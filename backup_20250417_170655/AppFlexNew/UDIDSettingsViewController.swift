import UIKit

class UDIDSettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections = ["当前UDID", "设置"]
    private var currentUDID: String = ""
    private var isCustomUDID: Bool = false
    
    private let udidTextField = UITextField()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentUDID = ServerController.shared.getCurrentUDID()
        isCustomUDID = ServerController.shared.hasCustomUDID()
        
        setupUI()
        tableView.dataSource = self
        tableView.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "设备UDID设置"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UDIDCell")
        tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveUDID))
    }
    
    @objc private func saveUDID() {
        guard let udid = udidTextField.text, !udid.isEmpty else {
            showAlert(title: "错误", message: "UDID不能为空")
            return
        }
        
        if !isValidUDID(udid) {
            showAlert(title: "错误", message: "UDID格式不正确，请输入有效的UDID")
            return
        }
        
        ServerController.shared.saveCustomUDID(udid)
        showAlert(title: "成功", message: "UDID已保存", completion: { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
    }
    
    @objc private func clearUDID() {
        let alert = UIAlertController(title: "确认", message: "确定要恢复使用系统默认UDID吗？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive, handler: { [weak self] _ in
            ServerController.shared.clearCustomUDID()
            self?.showAlert(title: "成功", message: "已恢复使用系统默认UDID", completion: { _ in
                self?.navigationController?.popViewController(animated: true)
            })
        }))
        
        present(alert, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: completion))
        present(alert, animated: true)
    }
    
    private func isValidUDID(_ udid: String) -> Bool {
        let pattern = "^[A-Fa-f0-9]{8,40}$" // 8-40个十六进制字符
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: udid.utf16.count)
        return regex?.firstMatch(in: udid, options: [], range: range) != nil
    }
    
    private func copyUDID() {
        UIPasteboard.general.string = currentUDID
        showAlert(title: "已复制", message: "UDID已复制到剪贴板")
    }
}

extension UDIDSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1 // 当前UDID
        } else {
            return isCustomUDID ? 2 : 1 // 输入框 + 可能的清除按钮
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UDIDCell", for: indexPath)
            cell.textLabel?.text = currentUDID
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
            cell.textLabel?.textColor = .systemGray
            cell.selectionStyle = .default
            return cell
        } else {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextFieldTableViewCell
                cell.configure(placeholder: "输入设备UDID", keyboardType: .asciiCapable)
                udidTextField.text = isCustomUDID ? currentUDID : ""
                udidTextField.placeholder = "输入设备UDID"
                udidTextField.keyboardType = .asciiCapable
                udidTextField.autocorrectionType = .no
                udidTextField.autocapitalizationType = .none
                cell.textField = udidTextField
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "UDIDCell", for: indexPath)
                cell.textLabel?.text = "恢复系统默认UDID"
                cell.textLabel?.textColor = .systemRed
                cell.textLabel?.textAlignment = .center
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return isCustomUDID ? "当前使用的是自定义UDID，点击可复制" : "当前使用的是系统生成的UDID，点击可复制"
        } else if section == 1 {
            return "输入您想要使用的UDID，通常由设备提供商或开发者提供"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            copyUDID()
        } else if indexPath.section == 1 && indexPath.row == 1 {
            clearUDID()
        }
    }
}

class TextFieldTableViewCell: UITableViewCell {
    
    var textField: UITextField! {
        didSet {
            setupTextField()
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    private func setupTextField() {
        if textField == nil {
            textField = UITextField()
        }
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }
    
    func configure(placeholder: String, keyboardType: UIKeyboardType = .default) {
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
    }
} 
