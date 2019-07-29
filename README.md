
>蓝牙打印机打印排版
>本次使用的是 Swift 5构建，蓝牙连接打印机打印

[TOC]

## 先上效果图 80MM打印 50MM 打印

备注两列自动换行、四列商品自动换行

![80.jpeg](https://upload-images.jianshu.io/upload_images/1339729-f7e65e0c3e4bc14f.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

![50.jpeg](https://upload-images.jianshu.io/upload_images/1339729-8feb6145b300186d.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

* 功能包含：
- [x] 两列排版
- [x] 两列左右侧标题自动换行
- [x] 三列排版
- [x] 四列排版
- [x] 四列排版自动换行
- [x] 根据打印纸的大小（50mm、80mm）自动排版
- [x] 对齐方式（两列左对齐、有对齐）
- [x] 单列左对齐、居中对齐、右对齐
- [x] 字体大小设置

## 使用方法
把BaseManager.swift 文件导入项目 

在需要使用的VC中

```Swift
    // 变量生命
    var manager:BaseManager?


    // 初始化
    if manager == nil{
        manager = BaseManager()
        manager?.delegate = self
        manager?.successBlock = {
            self.printerBtn.isEnabled = true
            print("连接成功")
            self.tableView.reloadData()
        }
    }
    
    // 接收搜索到打印机的回调
    extension ViewController: BaseManagerDelegate {
        func discoverPeripheral(_ peripheral: CBPeripheral) {
            peripheralArr.append(peripheral)
            tableView.reloadData()
        }
    }
    
    // 打印测试数据
    @objc func printTextAction() {
        manager?.testPrint()
    }

    

```

## 核心代码

```Swift

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

    
    //  两列 右侧文本自动换行 maxChar 个字符
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

```

## 代码中使用的的数字含义

```Swift 
    // 这些数字都是10进制的 ASCII码 
    let ESC:UInt8   = 27    //换码
    let FS:UInt8    = 28    //文本分隔符
    let GS:UInt8    = 29    //组分隔符
    let DLE:UInt8   = 16    //数据连接换码
    let EOT:UInt8   = 4     //传输结束
    let ENQ:UInt8   = 5     //询问字符
    let SP:UInt8    = 32    //空格
    let HT:UInt8    = 9     //横向列表
    let LF:UInt8    = 10    //打印并换行（水平定位）
    let ER:UInt8    = 13    //归位键
    let FF:UInt8    = 12    //走纸控制（打印并回到标准模式（在页模式下） ）
```

## 如何知道打印机支持的指令

本项目中有一个 <<58MM热敏打印机编程手册>> 这里面记录了，打印机支持的所有格式，可以自行查看





