//
//  ViewController.swift
//  BluethPrint
//
//  Created by administrator on 2018/11/19.
//  Copyright © 2018 administrator. All rights reserved.
//

import UIKit
import CoreBluetooth

let screenW = UIScreen.main.bounds.size.width
let screenH = UIScreen.main.bounds.size.height

class ViewController: UIViewController {
    var peripheralArr:[CBPeripheral] = []
    var tableView: UITableView!
    var manager:BaseManager?
    var printerBtn: UIButton!
    @objc func printTextAction() {
        manager?.testPrint()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.setValue(1, forKey: "printerNum")

        printerBtn = UIButton(type: UIButton.ButtonType.custom)
        printerBtn.frame = CGRect(x: screenW - 100, y: 40, width: 60, height: 60)
        printerBtn.setImage(UIImage(named: "dayin.png"), for: UIControl.State.normal)
        printerBtn.addTarget(self, action: #selector(printTextAction), for: UIControl.Event.touchUpInside)
        printerBtn.isEnabled = false
        self.view.addSubview(printerBtn)

        tableView = UITableView(frame: CGRect(x: 0, y: 100, width: screenW, height: screenH), style: UITableView.Style.plain)
        tableView.dataSource = self
        tableView.delegate = self
        self.view.addSubview(tableView)
        tableView.separatorStyle = .none

        if manager == nil{
            manager = BaseManager()
            manager?.delegate = self
            manager?.successBlock = {
                self.printerBtn.isEnabled = true
                print("连接成功")
                self.tableView.reloadData()
            }
        }
    }
}

extension ViewController: BaseManagerDelegate {
    func discoverPeripheral(_ peripheral: CBPeripheral) {
        peripheralArr.append(peripheral)
        tableView.reloadData()
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        manager?.connectPrinter(peripheral: peripheralArr[indexPath.row])
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "cell")
        }
        cell?.selectionStyle = .none
        cell?.textLabel?.text = peripheralArr[indexPath.row].name ?? "没有获取到设备名"
        cell?.detailTextLabel?.text = peripheralArr[indexPath.row].name == manager?.currentPeripheral?.name ? "已连接" : ""
        return cell!
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralArr.count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}
