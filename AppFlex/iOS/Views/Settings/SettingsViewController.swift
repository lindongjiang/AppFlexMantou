import UIKit
import SafariServices

class SettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections = ["社交媒体"] // 只保留社交媒体部分
    private var settings = [
        [] // 社交媒体链接将通过API动态填充
    ]
    private let jsonURL = "https://uni.cloudmantoub.online/mantou.json"
    private var socialLinks: [String: String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        tableView.dataSource = self
        tableView.delegate = self
        fetchSocialLinks()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    
    // 获取社交媒体链接
    private func fetchSocialLinks() {
        guard let url = URL(string: jsonURL) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("获取社交媒体链接失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let socialLinks = json["social_links"] as? [String: String] {
                    
                    self.socialLinks = socialLinks
                    
                    // 更新社交媒体部分
                    DispatchQueue.main.async {
                        self.settings[0] = Array(self.socialLinks.keys) // 更新为索引0
                        self.tableView.reloadData()
                    }
                }
            } catch {
                print("解析社交媒体链接失败: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // 打开社交媒体链接
    private func openSocialLink(_ url: String) {
        guard let url = URL(string: url) else {
            showAlert(title: "错误", message: "无效的URL")
            return
        }
        
        // 检查URL类型
        if url.absoluteString.contains("http") {
            // 网页链接使用SFSafariViewController打开
            let safariVC = SFSafariViewController(url: url)
            present(safariVC, animated: true)
        } else {
            // 其他类型的URL使用UIApplication打开
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showAlert(title: "错误", message: "无法打开此链接")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
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
        // 社交媒体部分使用自定义样式
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SocialCell")
        let linkName = settings[indexPath.section][indexPath.row] as! String
        cell.textLabel?.text = linkName
        
        // 根据链接类型设置不同的图标
        if let url = socialLinks[linkName] {
            if url.contains("qrr.jpg") {
                cell.imageView?.image = UIImage(systemName: "qrcode")
            } else if url.contains("t.me") {
                cell.imageView?.image = UIImage(systemName: "paperplane.fill")
            } else if url.contains("qq.com") {
                cell.imageView?.image = UIImage(systemName: "message.fill")
            } else {
                cell.imageView?.image = UIImage(systemName: "link")
            }
        }
        
        cell.accessoryType = .disclosureIndicator
        cell.imageView?.tintColor = .systemBlue
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 处理社交媒体链接
        let linkName = settings[indexPath.section][indexPath.row] as! String
        if let linkURL = socialLinks[linkName] {
            openSocialLink(linkURL)
        }
    }
} 