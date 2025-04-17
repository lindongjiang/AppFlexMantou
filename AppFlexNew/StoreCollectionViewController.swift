

import UIKit
import SafariServices

var globalDeviceUUID: String?

class StoreCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, SFSafariViewControllerDelegate {
    
    public struct AppData: Decodable {
        let id: String
        let name: String
        let date: String?
        let size: Int?
        let channel: String?
        let build: String?
        let version: String
        let identifier: String?
        let pkg: String?
        let icon: String
        let plist: String?
        let web_icon: String?
        let type: Int?
        let requires_key: Int
        let created_at: String?
        let updated_at: String?
        let requiresUnlock: Bool?
        let isUnlocked: Bool?
        
        var requiresKey: Bool {
            return requires_key == 1
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, date, size, channel, build, version, identifier, pkg, icon, plist
            case web_icon, type, requires_key, created_at, updated_at
            case requiresUnlock, isUnlocked
        }
    }

    struct APIResponse<T: Decodable>: Decodable {
        let success: Bool
        let data: T
        let message: String?
        let error: APIError?
    }

    struct APIError: Decodable {
        let code: String
        let details: String
    }

    struct UDIDStatus: Decodable {
        let bound: Bool
        let bindings: [Binding]?
    }
    
    struct Binding: Decodable {
        let id: Int
        let udid: String
        let card_id: Int
        let created_at: String
        let card_key: String
        
        enum CodingKeys: String, CodingKey {
            case id, udid
            case card_id
            case created_at
            case card_key
        }
    }

    private var apps: [AppData] = []
    private var deviceUUID: String {
        return globalDeviceUUID ?? UIDevice.current.identifierForVendor?.uuidString ?? "未知设备"
    }
    private var safariVC: SFSafariViewController?
    private let udidProfileURL = "https://uni.cloudmantoub.online/udid.mobileconfig"
    private let baseURL = "https://renmai.cloudmantoub.online/api/client"
    
    private var udidLabel: UILabel!
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        super.init(collectionViewLayout: layout)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewModel()
        setupCollectionView()
        
        title = "应用商店"
        
        let getUDIDButton = UIBarButtonItem(title: "获取UDID", style: .plain, target: self, action: #selector(getUDIDButtonTapped))
        
        navigationItem.rightBarButtonItems = [getUDIDButton]
        
        setupUDIDDisplay()
        
        checkForStoredUDID()
        
        fetchAppData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCardVerificationResult(_:)),
            name: NSNotification.Name("CardVerificationResult"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func applicationDidBecomeActive() {
    }
    
    private func setupUDIDDisplay() {
        let udidContainerView = UIView()
        udidContainerView.backgroundColor = UIColor.systemGray6
        udidContainerView.layer.cornerRadius = 10
        udidContainerView.layer.borderWidth = 1
        udidContainerView.layer.borderColor = UIColor.systemGray5.cgColor
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.systemGray
        titleLabel.text = "设备UDID:"
        
        udidLabel = UILabel()
        udidLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        udidLabel.textColor = UIColor.darkGray
        udidLabel.numberOfLines = 1
        udidLabel.adjustsFontSizeToFitWidth = true
        udidLabel.minimumScaleFactor = 0.7
        udidLabel.text = "获取中..."
        
        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemBlue
        copyButton.addTarget(self, action: #selector(copyUDIDButtonTapped), for: .touchUpInside)
        
        udidContainerView.addSubview(titleLabel)
        udidContainerView.addSubview(udidLabel)
        udidContainerView.addSubview(copyButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        udidLabel.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        udidContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(udidContainerView)
        
        NSLayoutConstraint.activate([
            udidContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            udidContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            udidContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            udidContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.leadingAnchor.constraint(equalTo: udidContainerView.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: udidContainerView.topAnchor, constant: 8),
            
            udidLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            udidLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            udidLabel.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            
            copyButton.trailingAnchor.constraint(equalTo: udidContainerView.trailingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: udidContainerView.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 40),
            copyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        collectionView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 0, right: 0)
    }
    
    @objc private func copyUDIDButtonTapped() {
        if let udid = globalDeviceUUID {
            UIPasteboard.general.string = udid
            
            let alert = UIAlertController(
                title: "已复制",
                message: "UDID已复制到剪贴板",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func checkForStoredUDID() {
        if let storedUDID = UserDefaults.standard.string(forKey: "deviceUDID") {
            globalDeviceUUID = storedUDID
            Debug.shared.log(message: "已加载存储的UDID: \(storedUDID)")
            
            updateUDIDDisplay(storedUDID)
            
        } else {
            Debug.shared.log(message: "未找到存储的UDID，需要获取")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                let alert = UIAlertController(
                    title: "需要获取UDID",
                    message: "为了正常使用应用安装功能，请点击获取UDID",
                    preferredStyle: .alert
                )
                
                let getUDIDAction = UIAlertAction(title: "立即获取", style: .default) { [weak self] _ in
                    self?.showUDIDProfileAlert()
                }
                
                let laterAction = UIAlertAction(title: "稍后再说", style: .cancel, handler: nil)
                
                alert.addAction(getUDIDAction)
                alert.addAction(laterAction)
                
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func updateUDIDDisplay(_ udid: String) {
        DispatchQueue.main.async { [weak self] in
            self?.udidLabel.text = udid
        }
    }
    
    private func showUDIDProfileAlert() {
        let alert = UIAlertController(
            title: "获取设备UDID",
            message: "系统将安装描述文件来获取UDID。安装完成后，请注意URL Scheme回调将自动导入UDID。",
            preferredStyle: .alert
        )
        
        let proceedAction = UIAlertAction(title: "继续", style: .default) { [weak self] _ in
            self?.openUDIDProfile()
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(proceedAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func openUDIDProfile() {
        guard let url = URL(string: udidProfileURL) else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUDIDCallback(_:)),
            name: NSNotification.Name("UDIDCallbackReceived"),
            object: nil
        )
        
        safariVC = SFSafariViewController(url: url)
        safariVC?.delegate = self
        present(safariVC!, animated: true, completion: nil)
    }
    
    @objc private func handleUDIDCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let udid = userInfo["udid"] as? String else {
            return
        }
        
        globalDeviceUUID = udid
        UserDefaults.standard.set(udid, forKey: "deviceUDID")
        Debug.shared.log(message: "成功通过URL Scheme获取并存储UDID: \(udid)")
        
        updateUDIDDisplay(udid)
        
        let alert = UIAlertController(
            title: "成功",
            message: "已成功获取设备UDID",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Debug.shared.log(message: "Safari已关闭，检查UDID状态")
        
    }

    private func fetchAppData() {
        let loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用列表...", preferredStyle: .alert)
        present(loadingAlert, animated: true, completion: nil)
        
        ServerController.shared.getAppList { [weak self] serverApps, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true, completion: nil)
                
                if let error = error {
                    let errorAlert = UIAlertController(
                        title: "获取应用失败",
                        message: "无法获取应用列表，请稍后再试。\n错误: \(error)",
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(errorAlert, animated: true)
                    return
                }
                
                guard let serverApps = serverApps else {
                    return
                }
                
                let convertedApps: [AppData] = serverApps.map { app in
                    let isUnlockedLocally = UserDefaults.standard.bool(forKey: "app_unlocked_\(app.id)")
                    
                    return AppData(
                        id: app.id,
                        name: app.name,
                        date: nil,
                        size: nil,
                        channel: nil,
                        build: nil,
                        version: app.version,
                        identifier: nil,
                        pkg: app.pkg,
                        icon: app.icon,
                        plist: app.plist,
                        web_icon: nil,
                        type: nil,
                        requires_key: app.requiresKey ? 1 : 0,
                        created_at: nil,
                        updated_at: nil,
                        requiresUnlock: app.requiresKey,
                        isUnlocked: isUnlockedLocally  // 使用本地存储的解锁状态
                    )
                }
                
                self?.apps = convertedApps
                self?.collectionView.reloadData()
            }
        }
    }

    private func checkUDIDStatus(for app: AppData) {
        guard let cleanUUID = globalDeviceUUID?
            .replacingOccurrences(of: "Optional(\"", with: "")
            .replacingOccurrences(of: "\")", with: ""),
            !cleanUUID.isEmpty else {
            return
        }

        guard let encodedUUID = cleanUUID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        let urlString = "\(baseURL)/check-udid?udid=\(encodedUUID)"
        guard let url = URL(string: urlString) else {
            return
        }
        
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                return
            }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<UDIDStatus>.self, from: data)
                DispatchQueue.main.async {
                    if response.success {
                        if response.data.bound {
                            
                            var hasAppBinding = false
                            if let bindings = response.data.bindings {
                                hasAppBinding = !bindings.isEmpty
                            }
                            
                            if hasAppBinding {
                                self?.fetchAppDetails(for: app)
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                                    guard let self = self else { return }
                                    self.promptUnlockCode(for: app)
                                }
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                                guard let self = self else { return }
                                self.promptUnlockCode(for: app)
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.promptUnlockCode(for: app)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.promptUnlockCode(for: app)
                    }
                }
            }
        }.resume()
    }

    private func verifyUnlockCode(_ code: String, for app: AppData) {
        ServerController.shared.verifyCard(cardKey: code, appId: app.id) { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                    UserDefaults.standard.set(true, forKey: "app_unlocked_\(app.id)")
                    
                    let alert = UIAlertController(
                        title: "验证成功",
                        message: message ?? "卡密验证成功",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                        let refreshAlert = UIAlertController(title: "刷新中", message: "正在刷新应用信息...", preferredStyle: .alert)
                        self?.present(refreshAlert, animated: true)
                        
                        ServerController.shared.refreshAppDetail(appId: app.id) { success, error in
                            DispatchQueue.main.async {
                                refreshAlert.dismiss(animated: true)
                                
                                if success {
                                    let successAlert = UIAlertController(
                                        title: "解锁成功",
                                        message: "应用已解锁，即将开始安装",
                                        preferredStyle: .alert
                                    )
                                    self?.present(successAlert, animated: true)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        successAlert.dismiss(animated: true) {
                                            var updatedApp = app
                                            let updatedAppData = AppData(
                                                id: app.id,
                                                name: app.name,
                                                date: app.date,
                                                size: app.size,
                                                channel: app.channel,
                                                build: app.build,
                                                version: app.version,
                                                identifier: app.identifier,
                                                pkg: app.pkg,
                                                icon: app.icon,
                                                plist: app.plist,
                                                web_icon: app.web_icon,
                                                type: app.type,
                                                requires_key: app.requires_key,
                                                created_at: app.created_at,
                                                updated_at: app.updated_at,
                                                requiresUnlock: true,
                                                isUnlocked: true
                                            )
                                            
                                            self?.fetchAppDetails(for: updatedAppData)
                                        }
                                    }
                                } else {
                                    let errorAlert = UIAlertController(
                                        title: "刷新失败",
                                        message: "应用详情刷新失败，但将尝试继续安装",
                                        preferredStyle: .alert
                                    )
                                    self?.present(errorAlert, animated: true)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        errorAlert.dismiss(animated: true) {
                                            let updatedAppData = AppData(
                                                id: app.id,
                                                name: app.name,
                                                date: app.date,
                                                size: app.size,
                                                channel: app.channel,
                                                build: app.build,
                                                version: app.version,
                                                identifier: app.identifier,
                                                pkg: app.pkg,
                                                icon: app.icon,
                                                plist: app.plist,
                                                web_icon: app.web_icon,
                                                type: app.type,
                                                requires_key: app.requires_key,
                                                created_at: app.created_at,
                                                updated_at: app.updated_at,
                                                requiresUnlock: true,
                                                isUnlocked: true
                                            )
                                            
                                            self?.fetchAppDetails(for: updatedAppData)
                                        }
                                    }
                                }
                            }
                        }
                    })
                } else {
                    let errorMessage = message ?? "请检查卡密是否正确"
                    
                    let alert = UIAlertController(
                        title: "验证失败",
                        message: errorMessage,
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.promptUnlockCode(for: app)
                        }
                    })
                    
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                    
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    private func handleInstall(for app: AppData) {
        if globalDeviceUUID == nil || globalDeviceUUID?.isEmpty == true {
            let alert = UIAlertController(
                title: "需要UDID",
                message: "安装应用前需要先获取设备UDID",
                preferredStyle: .alert
            )
            
            let getUDIDAction = UIAlertAction(title: "获取UDID", style: .default) { [weak self] _ in
                self?.showUDIDProfileAlert()
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            alert.addAction(getUDIDAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
            return
        }

        if app.requires_key == 1 {
            
            let isUnlocked = UserDefaults.standard.bool(forKey: "app_unlocked_\(app.id)")
            
            if !isUnlocked {
                fetchAppDetails(for: app)
                return
            } else {
            }
        }
        
        let isFreemiumApp = (app.requires_key == 0)
        var loadingAlert: UIAlertController?
        
        if isFreemiumApp {
            loadingAlert = UIAlertController(title: "准备安装", message: "正在获取安装信息...", preferredStyle: .alert)
            present(loadingAlert!, animated: true, completion: nil)
        }

        if let plist = app.plist, !plist.isEmpty {
            if isFreemiumApp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    loadingAlert?.dismiss(animated: true) {
                        self?.startInstallation(for: app)
                    }
                }
            } else {
                startInstallation(for: app)
            }
        } else {
            if isFreemiumApp {
                fetchAppDetails(for: app, loadingAlertShown: true, existingAlert: loadingAlert)
            } else {
                fetchAppDetails(for: app)
            }
        }
    }

    private func fetchAppDetails(for app: AppData, loadingAlertShown: Bool = false, existingAlert: UIAlertController? = nil) {
        var loadingAlert = existingAlert
        if !loadingAlertShown {
            loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用信息...", preferredStyle: .alert)
            present(loadingAlert!, animated: true, completion: nil)
        } else if loadingAlert != nil {
            loadingAlert?.message = "正在获取应用信息..."
        }
        
        if globalDeviceUUID == nil || globalDeviceUUID?.isEmpty == true {
            let deviceUUID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            globalDeviceUUID = deviceUUID
            updateUDIDDisplay(deviceUUID)
        }
        
        ServerController.shared.getAppDetail(appId: app.id) { [weak self] appDetail, error in
            DispatchQueue.main.async {
                loadingAlert?.dismiss(animated: true, completion: nil)
                
                if let error = error {
                    if app.requiresKey {
                        self?.promptUnlockCode(for: app)
                    } else {
                        let errorAlert = UIAlertController(
                            title: "获取应用信息失败",
                            message: "无法获取应用详细信息，请稍后再试。\n错误: \(error)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                    return
                }
                
                guard let appDetail = appDetail else {
                    if app.requiresKey {
                        self?.promptUnlockCode(for: app)
                    }
                    return
                }
                
                if (appDetail.requiresUnlock ?? false) && !(appDetail.isUnlocked ?? false) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.promptUnlockCode(for: app)
                    }
                } else {
                    if let plist = appDetail.plist {
                        
                        let updatedApp = AppData(
                            id: appDetail.id,
                            name: appDetail.name,
                            date: nil,
                            size: nil,
                            channel: nil,
                            build: nil,
                            version: appDetail.version,
                            identifier: nil,
                            pkg: appDetail.pkg,
                            icon: appDetail.icon,
                            plist: plist,
                            web_icon: nil,
                            type: nil,
                            requires_key: appDetail.requiresUnlock ? 1 : 0,
                            created_at: nil,
                            updated_at: nil,
                            requiresUnlock: appDetail.requiresUnlock,
                            isUnlocked: appDetail.isUnlocked
                        )
                        
                        if (updatedApp.requiresUnlock ?? false) && (updatedApp.isUnlocked ?? false) {
                            let successAlert = UIAlertController(
                                title: "解锁成功",
                                message: "应用「\(updatedApp.name)」已成功解锁，即将开始安装",
                                preferredStyle: .alert
                            )
                            
                            self?.present(successAlert, animated: true)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                successAlert.dismiss(animated: true) {
                                    self?.startInstallation(for: updatedApp)
                                }
                            }
                        } else {
                            self?.startInstallation(for: updatedApp)
                        }
                    } else {
                        let alert = UIAlertController(
                            title: "无法安装",
                            message: "此应用暂时无法安装，请稍后再试",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return apps.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AppCell", for: indexPath) as? AppCell else {
            return UICollectionViewCell()
        }
        let app = apps[indexPath.item]
        cell.configure(with: app)
        cell.onInstallTapped = { [weak self] in
            self?.handleInstall(for: app)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 30 // 减去左右的间距
        let height: CGFloat = 90 // 固定每个卡片的高度为 50
        return CGSize(width: width, height: height)
    }

    private func startInstallation(for app: AppData) {
        guard let plist = app.plist else {
            let alert = UIAlertController(
                title: "安装失败",
                message: "无法获取安装信息，请稍后再试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let finalPlistURL = processPlistLink(plist)
        
        let encodedPlistURL = finalPlistURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? finalPlistURL
        
        verifyPlistURL(encodedPlistURL)
        
        let installURLString = "itms-services://?action=download-manifest&url=\(encodedPlistURL)"
        
        if app.requires_key == 0 || ((app.requiresUnlock ?? false) && (app.isUnlocked ?? false)) {
            safelyOpenInstallURL(installURLString)
        } else {
            let alert = UIAlertController(
                title: "确认安装",
                message: "是否安装 \(app.name)？\n\n版本: \(app.version)",
                preferredStyle: .alert
            )

            let installAction = UIAlertAction(title: "安装", style: .default) { [weak self] _ in
                self?.safelyOpenInstallURL(installURLString)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            alert.addAction(installAction)
            alert.addAction(cancelAction)

            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func processPlistLink(_ plistLink: String) -> String {
        if plistLink.lowercased().hasPrefix("http") {
            return plistLink
        }
        
        if plistLink.hasPrefix("/") {
            if plistLink.hasPrefix("/api/plist/") {
                let components = plistLink.components(separatedBy: "/")
                if components.count >= 5 {
                    let fullURL = "https://renmai.cloudmantoub.online\(plistLink)"
                    return fullURL
                }
            }
            
            let fullURL = "https://renmai.cloudmantoub.online\(plistLink)"
            return fullURL
        }
        
        do {
            if let data = plistLink.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let iv = json["iv"] as? String,
                   let encryptedData = json["data"] as? String {
                    
                    if let decryptedURL = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                        return decryptedURL
                    }
                }
            }
        } catch {
        }
        
        if plistLink.contains("/api/plist/") && plistLink.contains("/") {
            let fullURL = plistLink.hasPrefix("http") ? plistLink : "https://renmai.cloudmantoub.online\(plistLink)"
            return fullURL
        }
        
        let components = plistLink.components(separatedBy: "/")
        if components.count == 2 {
            let possibleIV = components[0]
            let possibleData = components[1]
            
            let (valid, _) = CryptoUtils.shared.validateFormat(encryptedData: possibleData, iv: possibleIV)
            if valid {
                let apiPath = "/api/plist/\(possibleIV)/\(possibleData)"
                let fullURL = "https://renmai.cloudmantoub.online\(apiPath)"
                return fullURL
            }
        }
        
        return plistLink
    }
    
    private func verifyPlistURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 只获取头信息，不下载内容
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
        }.resume()
    }

    @objc private func showUDIDHelpGuide() {
        let helpVC = UIViewController()
        helpVC.title = "如何获取UDID"
        helpVC.view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        helpVC.view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: helpVC.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: helpVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: helpVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: helpVC.view.bottomAnchor)
        ])
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        let padding: CGFloat = 20
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "如何获取设备UDID"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        
        let introLabel = UILabel()
        introLabel.text = "UDID（唯一设备标识符）是每台iOS设备特有的识别码，安装某些应用需要提供此标识符。以下是获取UDID的步骤："
        introLabel.font = UIFont.systemFont(ofSize: 16)
        introLabel.numberOfLines = 0
        
        let step1Label = createStepLabel(number: 1, text: "在应用内点击\"获取UDID\"按钮")
        
        let step2Label = createStepLabel(number: 2, text: "Safari浏览器会打开一个网页，点击\"允许\"下载配置描述文件")
        
        let step3Label = createStepLabel(number: 3, text: "前往设置 -> 通用 -> VPN与设备管理，找到并点击下载的描述文件，然后点击\"安装\"")
        
        let step4Label = createStepLabel(number: 4, text: "完成安装后将显示UDID信息，网站会自动通过URL Scheme跳转回应用并传递UDID")
        
        let noteLabel = UILabel()
        noteLabel.text = "注意：此过程只需完成一次。一旦获取到UDID，应用会自动保存，无需重复操作。"
        noteLabel.font = UIFont.italicSystemFont(ofSize: 16)
        noteLabel.textColor = .systemGray
        noteLabel.numberOfLines = 0
        
        let startButton = UIButton(type: .system)
        startButton.setTitle("开始获取UDID", for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        startButton.backgroundColor = UIColor.tintColor
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 10
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            config.baseBackgroundColor = UIColor.tintColor
            config.baseForegroundColor = .white
            startButton.configuration = config
        } else {
            startButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        
        startButton.addTarget(self, action: #selector(getUDIDButtonTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(introLabel)
        stackView.addArrangedSubview(step1Label)
        stackView.addArrangedSubview(step2Label)
        stackView.addArrangedSubview(step3Label)
        stackView.addArrangedSubview(step4Label)
        stackView.addArrangedSubview(noteLabel)
        stackView.addArrangedSubview(startButton)
        
        for view in stackView.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true
        
        navigationController?.pushViewController(helpVC, animated: true)
    }

    private func createStepLabel(number: Int, text: String) -> UILabel {
        let label = UILabel()
        let attributedString = NSMutableAttributedString(string: "步骤 \(number): ", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.tintColor
        ])
        
        attributedString.append(NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]))
        
        label.attributedText = attributedString
        label.numberOfLines = 0
        return label
    }

    private func setupViewModel() {
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .systemBackground
        collectionView.register(AppCell.self, forCellWithReuseIdentifier: "AppCell")
    }

    private func extractUDID(from urlString: String) -> String? {
        if urlString.contains("/udid/") {
            let components = urlString.components(separatedBy: "/udid/")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func promptUnlockCode(for app: AppData) {
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: false) { [weak self] in
                self?.createAndShowUnlockAlert(for: app)
            }
        } else {
            createAndShowUnlockAlert(for: app)
        }
    }

    private func createAndShowUnlockAlert(for app: AppData) {
        let alert = UIAlertController(
            title: "安装",
            message: "应用「\(app.name)」需要卡密才能安装\n请输入有效的卡密继续",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "请输入卡密"
            textField.clearButtonMode = .whileEditing
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
        }
        
        let confirmAction = UIAlertAction(title: "安装", style: .default) { [weak self, weak alert] _ in
            guard let unlockCode = alert?.textFields?.first?.text, !unlockCode.isEmpty else {
                let errorAlert = UIAlertController(
                    title: "错误",
                    message: "卡密不能为空",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
                    self?.promptUnlockCode(for: app)
                })
                self?.present(errorAlert, animated: true)
                return
            }
            
            let verifyingAlert = UIAlertController(
                title: "验证中",
                message: "正在验证卡密，请稍候...",
                preferredStyle: .alert
            )
            self?.present(verifyingAlert, animated: true)
            
            self?.verifyUnlockCode(unlockCode, for: app)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                verifyingAlert.dismiss(animated: true)
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        if Thread.isMainThread {
            self.present(alert, animated: true) {
                alert.textFields?.first?.becomeFirstResponder()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.present(alert, animated: true) {
                    alert.textFields?.first?.becomeFirstResponder()
                }
            }
        }
    }

    @objc private func getUDIDButtonTapped() {
        showUDIDProfileAlert()
    }

    private func parseAppData(_ jsonString: String) -> AppData? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let id = json?["id"] as? String,
                  let name = json?["name"] as? String,
                  let version = json?["version"] as? String,
                  let icon = json?["icon"] as? String,
                  let requiresKey = json?["requires_key"] as? Int else {
                return nil
            }
            
            let date = json?["date"] as? String
            let size = json?["size"] as? Int
            let channel = json?["channel"] as? String
            let build = json?["build"] as? String
            let identifier = json?["identifier"] as? String
            let pkg = json?["pkg"] as? String
            let plist = json?["plist"] as? String
            let webIcon = json?["web_icon"] as? String
            let type = json?["type"] as? Int
            let createdAt = json?["created_at"] as? String
            let updatedAt = json?["updated_at"] as? String
            
            return AppData(
                id: id,
                name: name,
                date: date,
                size: size,
                channel: channel,
                build: build,
                version: version,
                identifier: identifier,
                pkg: pkg,
                icon: icon,
                plist: plist,
                web_icon: webIcon,
                type: type,
                requires_key: requiresKey,
                created_at: createdAt,
                updated_at: updatedAt,
                requiresUnlock: requiresKey == 1,
                isUnlocked: false
            )
        } catch {
            return nil
        }
    }
    
    private func handleAppJson(_ jsonString: String) {
        
        if let app = parseAppData(jsonString) {
            
            if let plist = app.plist {
                let loadingAlert = UIAlertController(title: "处理中", message: "正在准备安装...", preferredStyle: .alert)
                present(loadingAlert, animated: true) {
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        Thread.sleep(forTimeInterval: 0.5)
                        
                        DispatchQueue.main.async {
                            loadingAlert.dismiss(animated: true) {
                                let isReadyForDirectInstall = app.requires_key == 0 || ((app.requiresUnlock ?? false) && (app.isUnlocked ?? false))
                                
                                if isReadyForDirectInstall {
                                    self?.startInstallation(for: app)
                                } else {
                                    let confirmAlert = UIAlertController(
                                        title: "确认安装",
                                        message: "是否安装 \(app.name) 版本 \(app.version)？",
                                        preferredStyle: .alert
                                    )
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "安装", style: .default) { _ in
                                        self?.startInstallation(for: app)
                                    })
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel))
                                    
                                    self?.present(confirmAlert, animated: true)
                                }
                            }
                        }
                    }
                }
            } else {
                let alert = UIAlertController(
                    title: "无法安装",
                    message: "此应用暂时无法安装，请稍后再试",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        } else {
            let alert = UIAlertController(
                title: "应用解析失败",
                message: "无法解析应用数据，请稍后再试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    @objc private func handleManualInstall() {
        let alert = UIAlertController(
            title: "手动安装",
            message: "请粘贴应用JSON数据",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "粘贴JSON数据"
        }
        
        let installAction = UIAlertAction(title: "安装", style: .default) { [weak self] _ in
            if let jsonText = alert.textFields?.first?.text, !jsonText.isEmpty {
                self?.handleAppJson(jsonText)
            } else {
                self?.showError(title: "错误", message: "请输入有效的JSON数据")
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        alert.addAction(installAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func showError(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func safelyOpenInstallURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: { success in
                    if !success {
                        self.analyzeURLOpenFailure(urlString)
                    }
                })
            }
        } else {
            let modifiedURL = handlePotentiallyInvalidURL(urlString)
            if let url = URL(string: modifiedURL), modifiedURL != urlString {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            } else {
                showURLErrorAlert(urlString)
            }
        }
    }

    private func analyzeURLOpenFailure(_ urlString: String) {
        if urlString.contains(" ") {
            let trimmedURL = urlString.replacingOccurrences(of: " ", with: "%20")
            if let url = URL(string: trimmedURL) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        
        showURLErrorAlert(urlString)
    }

    private func handlePotentiallyInvalidURL(_ urlString: String) -> String {
        var modifiedURL = urlString
        let problematicCharacters = [" ", "<", ">", "#", "%", "{", "}", "|", "\\", "^", "~", "[", "]", "`"]
        
        for char in problematicCharacters {
            modifiedURL = modifiedURL.replacingOccurrences(of: char, with: urlEncodeCharacter(char))
        }
        
        return modifiedURL
    }

    private func urlEncodeCharacter(_ character: String) -> String {
        return character.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? character
    }

    private func showURLErrorAlert(_ urlString: String) {
        let alertMessage = """
        无法打开安装URL，可能原因：
        1. URL格式不正确
        2. URL长度过长(当前\(urlString.count)字符)
        3. iOS限制了itms-services协议
        
        请联系开发者解决此问题。
        """
        
        let alert = UIAlertController(
            title: "安装失败",
            message: alertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "复制URL", style: .default) { _ in
            UIPasteboard.general.string = urlString
        })
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }

    private func checkAppUnlockStatus(for appId: String) {
        
        let loadingAlert = UIAlertController(title: "检查中", message: "正在检查应用解锁状态...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        ServerController.shared.getAppDetail(appId: appId) { [weak self] appDetail, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true)
                
                if let error = error {
                    let errorAlert = UIAlertController(
                        title: "检查失败",
                        message: "无法获取应用状态：\(error)",
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(errorAlert, animated: true)
                    return
                }
                
                guard let appDetail = appDetail else {
                    let errorAlert = UIAlertController(
                        title: "检查失败",
                        message: "未获取到应用详情",
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(errorAlert, animated: true)
                    return
                }
                
                let statusMessage = """
                应用名称: \(appDetail.name)
                版本: \(appDetail.version)
                是否需要解锁: \(appDetail.requiresUnlock ?? false ? "是" : "否")
                是否已解锁: \(appDetail.isUnlocked ?? false ? "是" : "否")
                UDID: \(globalDeviceUUID ?? "未知")
                """
                
                let statusAlert = UIAlertController(
                    title: "应用状态",
                    message: statusMessage,
                    preferredStyle: .alert
                )
                
                statusAlert.addAction(UIAlertAction(title: "尝试安装", style: .default) { [weak self] _ in
                    if let plist = appDetail.plist {
                        let app = AppData(
                            id: appDetail.id,
                            name: appDetail.name,
                            date: nil,
                            size: nil,
                            channel: nil,
                            build: nil,
                            version: appDetail.version,
                            identifier: nil,
                            pkg: appDetail.pkg,
                            icon: appDetail.icon,
                            plist: plist,
                            web_icon: nil,
                            type: nil,
                            requires_key: appDetail.requiresUnlock ? 1 : 0,
                            created_at: nil,
                            updated_at: nil,
                            requiresUnlock: appDetail.requiresUnlock,
                            isUnlocked: appDetail.isUnlocked
                        )
                        self?.startInstallation(for: app)
                    } else {
                        let noPlAlert = UIAlertController(
                            title: "无法安装",
                            message: "应用缺少安装信息",
                            preferredStyle: .alert
                        )
                        noPlAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(noPlAlert, animated: true)
                    }
                })
                
                statusAlert.addAction(UIAlertAction(title: "输入卡密", style: .default) { [weak self] _ in
                    let tempApp = AppData(
                        id: appDetail.id,
                        name: appDetail.name,
                        date: nil,
                        size: nil,
                        channel: nil,
                        build: nil,
                        version: appDetail.version,
                        identifier: nil,
                        pkg: nil,
                        icon: appDetail.icon,
                        plist: nil,
                        web_icon: nil,
                        type: nil,
                        requires_key: 1,
                        created_at: nil,
                        updated_at: nil,
                        requiresUnlock: true,
                        isUnlocked: false
                    )
                    self?.promptUnlockCode(for: tempApp)
                })
                
                statusAlert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                
                self?.present(statusAlert, animated: true)
            }
        }
    }

    @objc private func handleCardVerificationResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let success = userInfo["success"] as? Bool,
              let appId = userInfo["appId"] as? String else {
            return
        }
        
        
        if success {
            let tempApp = AppData(
                id: appId,
                name: "应用",
                date: nil,
                size: nil,
                channel: nil,
                build: nil,
                version: "",
                identifier: nil,
                pkg: nil,
                icon: "",
                plist: nil,
                web_icon: nil,
                type: nil,
                requires_key: 1,
                created_at: nil,
                updated_at: nil,
                requiresUnlock: true,
                isUnlocked: true
            )
            
            fetchAppDetails(for: tempApp)
        }
    }
}

class AppCell: UICollectionViewCell {
    private let appIcon = UIImageView()
    private let nameLabel = UILabel()
    private let versionLabel = UILabel()
    private let installButton = UIButton(type: .system)
    private let freeLabel = UILabel() // 添加限免标签
    private var isFreemiumApp = false // 添加标记是否为免费应用

    var onInstallTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 15
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowRadius = 5

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, versionLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 5
        textStackView.alignment = .leading

        let stackView = UIStackView(arrangedSubviews: [appIcon, textStackView, installButton])
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.alignment = .center
        stackView.distribution = .fill

        contentView.addSubview(stackView)
        
        freeLabel.text = "限免"
        freeLabel.textColor = .white
        freeLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        freeLabel.backgroundColor = UIColor.systemRed
        freeLabel.textAlignment = .center
        freeLabel.layer.cornerRadius = 10
        freeLabel.layer.masksToBounds = true
        freeLabel.layer.borderWidth = 1
        freeLabel.layer.borderColor = UIColor.white.cgColor
        freeLabel.isHidden = true // 初始隐藏
        
        contentView.addSubview(freeLabel)
        
        freeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            freeLabel.topAnchor.constraint(equalTo: appIcon.topAnchor),
            freeLabel.leadingAnchor.constraint(equalTo: appIcon.leadingAnchor, constant: -5),
            freeLabel.widthAnchor.constraint(equalToConstant: 40),
            freeLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
        ])

        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 70).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 70).isActive = true

        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .darkGray
        versionLabel.font = UIFont.systemFont(ofSize: 14, weight: .light)
        versionLabel.textColor = .lightGray

        installButton.backgroundColor = .systemBlue
        installButton.layer.cornerRadius = 10
        installButton.setTitle("安装", for: .normal)
        installButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        installButton.tintColor = .white
        installButton.frame.size = CGSize(width: 100, height: 40)  // 固定按钮大小
        installButton.addTarget(self, action: #selector(installTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with app: StoreCollectionViewController.AppData) {
        nameLabel.text = app.name
        
        let isUnlockedLocally = UserDefaults.standard.bool(forKey: "app_unlocked_\(app.id)")
        
        if app.requires_key == 0 {
            isFreemiumApp = true
            freeLabel.isHidden = true
            
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemGreen
            
            installButton.backgroundColor = .systemGreen
            installButton.setTitle("免费安装", for: .normal)
        } else if (app.requiresUnlock ?? false) && ((app.isUnlocked ?? false) || isUnlockedLocally) {
            isFreemiumApp = true  // 使用相同的动画效果
            freeLabel.isHidden = true
            
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemBlue
            
            installButton.backgroundColor = .systemBlue
            installButton.setTitle("安装", for: .normal)
        } else {
            isFreemiumApp = false
            freeLabel.isHidden = true
            
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemOrange
            
            installButton.backgroundColor = .systemOrange
            installButton.setTitle("安装", for: .normal)
        }
        
        if let url = URL(string: app.icon) {
            loadImage(from: url, into: appIcon)
        }
    }

    @objc private func installTapped() {
        if isFreemiumApp {
            UIView.animate(withDuration: 0.15, animations: {
                self.installButton.alpha = 0.6
                self.installButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.installButton.setTitle("处理中...", for: .normal)
            }, completion: { _ in
                self.onInstallTapped?()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    UIView.animate(withDuration: 0.2) {
                        self.installButton.alpha = 1.0
                        self.installButton.transform = .identity
                        if self.installButton.backgroundColor == .systemGreen {
                            self.installButton.setTitle("免费安装", for: .normal)
                        } else {
                            self.installButton.setTitle("安装", for: .normal)
                        }
                    }
                }
            })
        } else {
            UIView.animate(withDuration: 0.1, animations: {
                self.installButton.alpha = 0.7
                self.installButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }, completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.installButton.alpha = 1.0
                    self.installButton.transform = .identity
                }
                self.onInstallTapped?()
            })
        }
    }

    private func loadImage(from url: URL, into imageView: UIImageView) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                    imageView.layer.cornerRadius = imageView.frame.size.width / 2
                    imageView.clipsToBounds = true
                }
            }
        }
    }
}
