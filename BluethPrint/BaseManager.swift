//
//  BaseManager.swift
//  WorldDoctor
//
//  Created by administrator on 2018/9/5.
//  Copyright © 2018年 CxDtreeg. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol BaseManagerDelegate {
    func discoverPeripheral(_ peripheral: CBPeripheral)
}

class BaseManager: NSObject {
    var successBlock:(()->Void)?
    var delegate: BaseManagerDelegate?
    var command = Printer()
    var manager: CBCentralManager!
    var currentPeripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic!
    var readCharacteristic: CBCharacteristic!
    var currentServiceUUID: String?
    var currentWriteUUID: String?
    var currentScanName: String?
    let serviceId = "49535343-FE7D-4AE5-8FA9-9FAFD205E455"
    let WriteUUID = "49535343-8841-43F4-A8D4-ECBE34729BB3"
    
    override init() {
        super.init()
        self.manager = CBCentralManager(delegate: nil, queue: nil)
        self.manager.delegate = self;
        currentServiceUUID = serviceId
        currentWriteUUID = WriteUUID
        currentScanName = "Printer"
        updatePrinter()
    }
    
    func updatePrinter() {
        //        发现设备 调用之后 中心管理者会为他的委托对象调用
        manager.scanForPeripherals(withServices: nil, options: nil)
    }
    //  链接设备
    func connectPrinter(peripheral: CBPeripheral) {
        if peripheral.name != currentPeripheral?.name && currentPeripheral != nil {
            manager.cancelPeripheralConnection(currentPeripheral!)
        }
        currentPeripheral = peripheral
        manager.connect(peripheral, options: nil)
    }
    
}

extension BaseManager: CBCentralManagerDelegate {
    //    1.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        var message = "";
        switch central.state {
        case .unknown:
            message = "蓝牙系统错误"
        case .resetting:
            message = "请重新开启手机蓝牙"
        case .unsupported:
            message = "该手机不支持蓝牙"
        case .unauthorized:
            message = "蓝牙验证失败"
        case .poweredOff://蓝牙没开启，直接到设置
            message = "蓝牙没有开启"
            
        case .poweredOn:
            central.scanForPeripherals(withServices: nil, options: nil)
        }
        print(message)
    }
    
    //    2
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        print("设备名-->"+(peripheral.name ?? ""))
        let peripheralName = peripheral.name ?? ""
        let contains = (self.currentScanName != nil) && peripheralName.contains(self.currentScanName!)

        if contains {
            self.delegate?.discoverPeripheral(peripheral)
            //            currentPeripheral = peripheral
            //            central.connect(peripheral, options: nil)
        }
    }
    //    3
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //        链接成功之后 停止扫描
        central.stopScan()
        successBlock?()
        //蓝牙连接成功
        if currentPeripheral != nil {
            currentPeripheral!.delegate = self
            currentPeripheral!.discoverServices([CBUUID(string: self.currentServiceUUID!)])
        }
        
    }
}
extension BaseManager: CBPeripheralDelegate {
    //发现服务
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("当前currentServiceUUID-->"+(self.currentServiceUUID ?? ""))

        for service in peripheral.services! {
            print("寻找服务，服务有：\(service)"+"   id-->"+service.uuid.uuidString)
            if service.uuid.uuidString == self.currentServiceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
                print("找到当前服务了。。。。")
                break
            }
        }
    }
    
    //发现特征
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
            print("特征有\(characteristic)")
            
            if characteristic.uuid.uuidString == self.currentWriteUUID {
                self.writeCharacteristic = characteristic
                print("-找到了写服务----\(characteristic)")
            }
        }
    }
    
    ///发送指令给打印机
    private func send(value:Data) {
        
        currentPeripheral!.writeValue(value, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    ///打印文字
    func printText(_ str:String) {
        
        let enc = CFStringConvertEncodingToNSStringEncoding(UInt32(CFStringEncodings.GB_18030_2000.rawValue))
        
        ///这里一定要GB_18030_2000，测试过用utf-系列是乱码，踩坑了。
        let data = str.data(using: String.Encoding(rawValue: enc), allowLossyConversion: false)
        if data != nil{
            sendCommand(data!)
        }
    }
    ///发送指令
    func sendCommand(_ data:Data) {
        send(value: data)
    }
    
    ///测试打印
    func testPrint() {
        sendCommand(command.clear())
        sendCommand(command.mergerPaper())
        sendCommand(command.alignLeft())
        sendCommand(command.fontSize(font: 0))

        let dataArr = command.printFourDataAutoLine(leftText: "第一列数", middleLeftText: "第二列数据第二列数据", middleRIghtText: "第三列数据第三列数据第三列数据", rightText: "第四列数据第四列数据第四列数据第四列数据")
        for data in dataArr {
            sendCommand(data)
        }
    }
}


///这个类参考的 https://blog.csdn.net/a214024475/article/details/52996047 ，向大神致敬。
class Printer
{
    ///一行最多打印字符个数
    let kRowMaxLength = 32
    
    let ESC:UInt8 = 27//换码
    let FS:UInt8 = 28//文本分隔符
    let GS:UInt8 = 29//组分隔符
    let DLE:UInt8 = 16//数据连接换码
    let EOT:UInt8 = 4//传输结束
    let ENQ:UInt8 = 5//询问字符
    let SP:UInt8 = 32//空格
    let HT:UInt8 = 9//横向列表
    let LF:UInt8 = 10//打印并换行（水平定位）
    let ER:UInt8 = 13//归位键
    let FF:UInt8 = 12//走纸控制（打印并回到标准模式（在页模式下） ）
    
    /*------------------------------------------------------------------------------------------------*/

    let enc = CFStringConvertEncodingToNSStringEncoding(UInt32(CFStringEncodings.GB_18030_2000.rawValue))


    var maxLine = 0
    /**
     * 打印四列 自动换行
     * max 最大4字
     * @param leftText   左侧文字
     * @param middleLeftText 中间左文字
     * @param middleRIghtText 中间右文字
     * @param rightText  右侧文字
     * @return
     */
    func printFourDataAutoLine(leftText: String, middleLeftText: String, middleRIghtText: String, rightText: String) ->[Data]{
        // 存放打印的数据（data）
        var printerAllDataArr: [Data] = []
        // 每一列可显示汉子的个数
        let maxTextCount = LINE_BYTE_SIZE/4
        maxLine = 0
        let leftStrArr = printStrArrWithText(text: leftText, maxTextCount: maxTextCount)
        var middleLeftStrArr = printStrArrWithText(text: middleLeftText, maxTextCount: maxTextCount)
        var middleRightStrArr = printStrArrWithText(text: middleRIghtText, maxTextCount: maxTextCount)
        var rightStrArr = printStrArrWithText(text: rightText, maxTextCount: maxTextCount)
        for i in 0..<maxLine {
            let data = printFourData(leftText: leftStrArr[i], middleLeftText: middleLeftStrArr[i], middleRIghtText: middleRightStrArr[i], rightText: rightStrArr[i])
            printerAllDataArr.append(data)
        }
        return printerAllDataArr
    }

    // 字符串根据一行最大值maxTextCount分成数组
    func printStrArrWithText(text: String,maxTextCount: Int) -> [String] {
        let enc = CFStringConvertEncodingToNSStringEncoding(UInt32(CFStringEncodings.GB_18030_2000.rawValue))

        var textArr:[String] = []
        let textData = setTitle(text: text) as NSData
        let textLength = textData.length
        if textLength > maxTextCount {
            // 需要几行
            let lines = textLength / maxTextCount
            // 余数
            let remainder = textLength % maxTextCount
            // 设置最大支持7行
            for i in 0..<lines {
                let temp = textData.subdata(with: NSMakeRange(i*maxTextCount, maxTextCount))
                let str = String(data: temp, encoding: String.Encoding(rawValue: enc))
                if str == nil {
                    let temp = textData.subdata(with: NSMakeRange(i*(maxTextCount-1), maxTextCount))
                    let str = String(data: temp, encoding: String.Encoding(rawValue: enc))
                    if str != nil {
                        textArr.append(str!)
                    }
                }else {
                    textArr.append(str!)
                }
            }
            // 记录的值 小于当先行书 并且 有余数 就lines+1 否则 记录lines
            if maxLine < lines && remainder != 0{
                maxLine = lines + 1
            }else if maxLine < lines && remainder == 0{
                maxLine = lines
            }
            if remainder != 0 {
                let temp = textData.subdata(with: NSMakeRange(lines*maxTextCount, remainder))
                let str = String(data: temp, encoding: String.Encoding(rawValue: enc))
                textArr.append(str!)
            }
        }else { // 文本没有超过限制
            if maxLine == 0 {
                maxLine = 1
            }
            textArr.append(text)
        }
        if textArr.count < 5 { // 最多支持5
            for _ in 0..<5-textArr.count {
                textArr.append("")
            }
        }
        return textArr
    }

    //  两列 右侧文本自动换行 maxChar 个汉子
    func setRightTextAutoLine(left: String,right: String,maxText:Int)->Data {

        // 存放打印的数据（data）
        let printerData: NSMutableData = NSMutableData.init()

        let valueCount = right.count
        if valueCount > maxText {
            // 需要几行
            let lines = valueCount / maxText
            // 余数
            let remainder = valueCount % maxText
            for i in 0..<lines {
                let index1 = right.index(right.startIndex, offsetBy: i*maxText)
                let index2 = right.index(right.startIndex, offsetBy: i*maxText + maxText)
                let sub1 = right[index1..<index2]
                print(sub1)
                if i == 0 {
                    let tempData = printTwoData(leftText: left, rightText: String(sub1))
                    printerData.append(tempData)
                }else {
                    let tempData = printTwoData(leftText: "", rightText: String(sub1))
                    printerData.append(tempData)
                }
            }
            if remainder != 0 {
                let index1 = right.index(right.startIndex, offsetBy: lines*maxText)
                let index2 = right.index(right.startIndex, offsetBy: lines*maxText + remainder)
                let sub1 = right[index1..<index2]
                print(sub1)
                let tempData = printTwoData(leftText: "", rightText: String(sub1))
                printerData.append(tempData)
            }
        }else {
            let tempData = printTwoData(leftText: left, rightText: right)
            printerData.append(tempData)
        }

        let lineData = nextLine(number: 1)
        printerData.append(lineData)
        return printerData as Data
    }


    //   text 内容。value 右侧内容 左侧列 支持的最大显示 超过四字自动换行
    //  两列 左侧文本自动换行
    func setLeftTextLine(text: String,value: String,maxChar:Int)->Data {
        let data = text.data(using: String.Encoding(rawValue: enc))! as NSData

        if (data.length > maxChar) {
            let lines = data.length / maxChar
            let remainder = data.length % maxChar
            var tempData: NSMutableData = NSMutableData.init()
            for i in 0..<lines {
                let temp = (data.subdata(with: NSMakeRange(i*maxChar, maxChar)) as NSData)
                tempData.append(temp.bytes, length: temp.length)
                if i == 0 {
                    let data = setOffsetText(value: value)
                    tempData.append(data.bytes, length: data.length)
                }
                let line = nextLine(number: 1) as NSData
                tempData.append(line.bytes, length: line.length)
            }
            if remainder != 0 { // 余数不0
                let temp = data.subdata(with: NSMakeRange(lines*maxChar, remainder)) as NSData
                tempData.append(temp.bytes, length: temp.length)
            }
            return tempData as Data
        }
        let rightTextData = setOffsetText(value: value)
        let mutData = NSMutableData.init(data: data as Data)
        mutData.append(rightTextData.bytes, length: rightTextData.length)
        return mutData as Data
    }

    // 添加文字，不换行
    func setTitle(text: String) -> Data {
        let enc = CFStringConvertEncodingToNSStringEncoding(UInt32(CFStringEncodings.GB_18030_2000.rawValue))
        ///这里一定要GB_18030_2000，测试过用utf-系列是乱码，踩坑了。
        let data = text.data(using: String.Encoding(rawValue: enc), allowLossyConversion: false)
        if data != nil{
            return data!
        }
        return Data()
    }
    /**
     *  设置偏移文字
     *
     *  @param value 右侧内容
     */
    func setOffsetText(value: String) -> NSData {
        let attributes = [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 22.0)] //设置字体大小
        let option = NSStringDrawingOptions.usesLineFragmentOrigin
        //获取字符串的frame
        let rect:CGRect = value.boundingRect(with: CGSize.init(width: 320.0, height: 999.9), options: option, attributes: attributes, context: nil)
        let valueWidth: Int = Int(rect.size.width)
        let preNum = (UserDefaults.standard.value(forKey: "printerNum") ?? 0) as! Int
        let offset = (preNum == 0 ? 384 : 576) - valueWidth - 30
        let remainder = offset % 256
        let consult = offset / 256;
        var foo:[UInt8] = [0x1B, 0x24]
        foo.append(UInt8(remainder))
        foo.append(UInt8(consult))
        let data = Data.init(bytes: foo) as NSData
        let mutData = NSMutableData.init()
        mutData.append(data.bytes, length: data.length)
        let titleData = setTitle(text: value) as NSData
        mutData.append(titleData.bytes, length: titleData.length)
        return mutData as NSData
    }
    //    添加横线 默认32位
    func addImaginaryLine() -> Data {
        let preNum = (UserDefaults.standard.value(forKey: "printerNum") ?? 0) as! Int
        let paperWidth = (preNum == 0 ? 384 : 576)
        var number: Int = 0
        if paperWidth == 384 {
            number = 32
        }else {
            number = 48
        }
        var foo:[UInt8] = []
        for _ in 0..<number {
            foo.append(45)
        }
        foo.append(LF)
        return Data.init(bytes:foo)
    }

    // FS S n1 n2 设置汉字字符左右间距 0<= 255
    func setHanZiEdge() ->Data {
        var foo:[UInt8] = []
        foo.append(28)// 固定
        foo.append(83)// 固定
        foo.append(10)// 左间距
        foo.append(0) // 右间距
        return Data.init(bytes: foo)
    }

    /**
     * 打印纸一行最大的字节 32 / 46
     */
    let LINE_BYTE_SIZE = 48;
    /**
     * 打印三列时，中间一列的中心线距离打印纸左侧的距离
     */
    let LEFT_LENGTH = 24;
    /**
     * 打印三列时，中间一列的中心线距离打印纸右侧的距离
     */
    let RIGHT_LENGTH = 24;
    /**
     * 打印三列时，第一列汉字最多显示几个文字
     */
    let LEFT_TEXT_MAX_LENGTH = 5;

    // 打印两列
    func printTwoData(leftText: String, rightText: String) ->Data {
        var strText = ""
        let leftTextLength = (setTitle(text: leftText) as NSData).length
        let rightTextLength = (setTitle(text: rightText)  as NSData).length
        strText = strText + leftText

        // 计算文字中间的空格
        let marginBetweenMiddleAndRight = LINE_BYTE_SIZE - leftTextLength - rightTextLength;
        for _ in 0..<marginBetweenMiddleAndRight {
            strText = strText + " "
        }
        strText = strText + rightText


        let data = NSMutableData()
        let lineData = nextLine(number: 1)
        data.append(setTitle(text: strText))
        data.append(lineData)
        return data as Data
    }

    /**
     * 打印三列
     *
     * @param leftText   左侧文字
     * @param middleText 中间文字
     * @param rightText  右侧文字
     * @return
     */
    func printThreeData(leftText: String, middleText: String, rightText: String) ->String{
        var strText = ""

        let leftTextLength = (setTitle(text: leftText) as NSData).length
        let middleTextLength = (setTitle(text: middleText)  as NSData).length
        let rightTextLength = (setTitle(text: rightText)  as NSData).length

        strText = strText + leftText

        // 计算左侧文字和中间文字的空格长度
        let marginBetweenLeftAndMiddle = LEFT_LENGTH - leftTextLength - middleTextLength / 2;
        for _ in 0..<marginBetweenLeftAndMiddle {
            strText = strText + " "
        }
        strText = strText + middleText

        // 计算右侧文字和中间文字的空格长度
        let marginBetweenMiddleAndRight = RIGHT_LENGTH - middleTextLength / 2 - rightTextLength;

        for _ in 0..<(marginBetweenMiddleAndRight) {
            strText = strText + " "
        }
        strText = strText + rightText
        return strText
    }

    /**
     * 打印四列
     *
     * @param leftText   左侧文字
     * @param middleLeftText 中间左文字
     * @param middleRIghtText 中间右文字
     * @param rightText  右侧文字
     * @return
     */
    func printFourData(leftText: String, middleLeftText: String, middleRIghtText: String, rightText: String) ->Data{
        var strText = ""
        let width = LINE_BYTE_SIZE/4
        let leftTextLength = (setTitle(text: leftText) as NSData).length
        let middleLeftTextLength = (setTitle(text: middleLeftText) as NSData).length
        let middleRIghtTextLength = (setTitle(text: middleRIghtText) as NSData).length
        let rightTextLength = (setTitle(text: rightText) as NSData).length

        strText = strText + leftText

        // 计算左侧文字和左1文字的空格长度
        let marginLeftAndLeftMiddle = width - leftTextLength + (width/2 - middleLeftTextLength/2);
        for _ in 0..<marginLeftAndLeftMiddle {
            strText = strText + " "
        }
        strText = strText + middleLeftText

        // 计算左侧文字和中间文字的空格长度
        let marginBetweenLeftAndMiddle = width - middleLeftTextLength/2 - middleRIghtTextLength/2;
        for _ in 0..<marginBetweenLeftAndMiddle {
            strText = strText + " "
        }
        strText = strText + middleRIghtText

        // 计算左侧文字和中间文字的空格长度
        let marginBetweenRightAndMiddle = width - rightTextLength + (width/2-middleRIghtTextLength/2);
        for i in 0..<marginBetweenRightAndMiddle {
            if i == marginBetweenRightAndMiddle - 1 {

            }else {
                strText = strText + " "
            }
        }
        strText = strText + rightText
        let data = NSMutableData()
        let lineData = nextLine(number: 1)
        data.append(setTitle(text: strText))
        data.append(lineData)
        return data as Data
    }
    /*------------------------------------------------------------------------------------------------*/

    ///初始化打印机
    func clear() -> Data {
        return Data.init(bytes:[ESC, 64])
    }
    
    ///打印空格
    func printBlank(number:Int) -> Data {
        var foo:[UInt8] = []
        for _ in 0..<number {
            foo.append(SP)
        }
        return Data.init(bytes:foo)
    }
    
    ///换行
    func nextLine(number:Int) -> Data {
        var foo:[UInt8] = []
        for _ in 0..<number {
            foo.append(LF)
        }
        return Data.init(bytes:foo)
    }

    ///回车
    func enter() -> Data {
        return Data.init(bytes: [13])
    }
    
    ///绘制下划线
    func printUnderline() -> Data {
        var foo:[UInt8] = []
        foo.append(ESC)
        foo.append(45)
        foo.append(1)//一个像素
        return Data.init(bytes:foo)
    }
    
    ///取消绘制下划线
    func cancelUnderline() -> Data {
        var foo:[UInt8] = []
        foo.append(ESC)
        foo.append(45)
        foo.append(0)
        return Data.init(bytes:foo)
    }
    
    ///加粗文字
    func boldOn() -> Data {
        var foo:[UInt8] = []
        foo.append(ESC)
        foo.append(69)
        foo.append(0xF)
        return Data.init(bytes:foo)
    }
    
    ///取消加粗
    func boldOff() -> Data {
        var foo:[UInt8] = []
        foo.append(ESC)
        foo.append(69)
        foo.append(0)
        return Data.init(bytes:foo)
    }
    
    ///左对齐
    func alignLeft() -> Data {
        return Data.init(bytes:[ESC,97,0])
    }
    
    ///居中对齐
    func alignCenter() -> Data {
        return Data.init(bytes:[ESC,97,1])
    }
    
    ///右对齐
    func alignRight() -> Data {
        return Data.init(bytes:[ESC,97,2])
    }
    
    ///水平方向向右移动col列
    func alignRight(col:UInt8) -> Data {
        var foo:[UInt8] = []
        foo.append(ESC)
        foo.append(68)
        foo.append(col)
        foo.append(0)
        return Data.init(bytes:foo)
    }
    
    ///字体变大为标准的n倍
    func fontSize(font:Int8) -> Data {
        var realSize:UInt8 = 0
        switch font {
        case 1:
            realSize = 0
        case 2:
            realSize = 17
        case 3:
            realSize = 34
        case 4:
            realSize = 51
        case 5:
            realSize = 68
        case 6:
            realSize = 85
        case 7:
            realSize = 102
        case 8:
            realSize = 119
        default:
            break
        }
        //
        var foo:[UInt8] = []
        foo.append(GS)
        foo.append(33)
        foo.append(realSize)
        return Data.init(bytes:foo)
    }
    
    ///进纸并全部切割
    func feedPaperCutAll() -> Data {
        var foo:[UInt8] = []
        foo.append(GS)
        foo.append(86)
        foo.append(65)
        foo.append(0)
        return Data.init(bytes:foo)
    }
    
    ///进纸并切割（左边留一点不切）
    func feedPaperCutPartial() -> Data {
        var foo:[UInt8] = []
        foo.append(GS)
        foo.append(86)
        foo.append(66)
        foo.append(0)
        return Data.init(bytes:foo)
    }
    
    ///设置纸张间距为默认
    func mergerPaper() -> Data {
        return Data.init(bytes:[ESC,109])
    }
}















