import UIKit

class SettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections = ["应用信息", "设备设置", "关于"]
    private let settings = [
        ["版本", "清除缓存"],
        ["设备UDID", "主题", "字体大小"],
        ["关于我们", "联系开发者", "意见反馈"]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 刷新表格以更新UDID状态
        tableView.reloadData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "设置"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }
    
    // 显示UDID设置界面
    private func showUDIDSettings() {
        let udidVC = UDIDSettingsViewController()
        navigationController?.pushViewController(udidVC, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        
        // 重置单元格样式
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .disclosureIndicator
        
        cell.textLabel?.text = settings[indexPath.section][indexPath.row]
        
        // 为UDID设置添加详细信息
        if indexPath.section == 1 && indexPath.row == 0 {
            // 使用子标题样式单元格显示UDID状态
            let styledCell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsDetailCell")
            styledCell.textLabel?.text = settings[indexPath.section][indexPath.row]
            
            if ServerController.shared.hasCustomUDID() {
                styledCell.detailTextLabel?.text = "已设置"
                styledCell.detailTextLabel?.textColor = .systemGreen
            } else {
                styledCell.detailTextLabel?.text = "系统默认"
                styledCell.detailTextLabel?.textColor = .systemGray
            }
            
            styledCell.accessoryType = .disclosureIndicator
            return styledCell
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 处理设置项点击
        let selectedSetting = settings[indexPath.section][indexPath.row]
        print("选择了设置: \(selectedSetting)")
        
        // 处理UDID设置
        if indexPath.section == 1 && indexPath.row == 0 {
            showUDIDSettings()
        }
    }
} 