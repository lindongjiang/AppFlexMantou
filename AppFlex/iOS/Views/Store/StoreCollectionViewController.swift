//
//  StoreCollectionViewController.swift
//  AppFlex
//
//  Created by mantou on 2025/2/17.
//  Copyright © 2025 AppFlex. All rights reserved.
//

import UIKit
import SafariServices

// 全局变量，现在使用KeyChain UUID替代UDID
var globalDeviceUUID: String? = KeychainUUID.getUUID()

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
        // 直接使用Keychain UUID，无需复杂的回退逻辑
        return globalDeviceUUID ?? KeychainUUID.getUUID()
    }
    
    private var baseURL: String {
        return AppSecurityManager.shared.buildAPIURL(path: "/api/client")
    }
    
    private var udidLabel: UILabel!
    
    // 自定义初始化方法，提供默认的布局
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
        
        // 移除获取UDID按钮
        // 添加刷新按钮替代
        let refreshButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshButtonTapped))
        navigationItem.rightBarButtonItems = [refreshButton]
        
        // 添加设备ID显示区域
        setupUDIDDisplay()
        
        // 使用KeyChain获取UUID并显示
        initializeDeviceID()
        
        // 添加卡密验证结果的通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCardVerificationResult(_:)),
            name: NSNotification.Name("CardVerificationResult"),
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 在视图完全加载后获取应用列表
        if apps.isEmpty {
            fetchAppData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func refreshButtonTapped() {
        // 刷新应用列表
        fetchAppData()
    }
    
    private func setupUDIDDisplay() {
        // 创建显示设备ID的容器视图
        let udidContainerView = UIView()
        udidContainerView.backgroundColor = UIColor.systemGray6
        udidContainerView.layer.cornerRadius = 10
        udidContainerView.layer.borderWidth = 1
        udidContainerView.layer.borderColor = UIColor.systemGray5.cgColor
        
        // 创建标题标签
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.systemGray
        titleLabel.text = "设备标识:"
        
        // 创建设备ID标签
        udidLabel = UILabel()
        udidLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        udidLabel.textColor = UIColor.darkGray
        udidLabel.numberOfLines = 1
        udidLabel.adjustsFontSizeToFitWidth = true
        udidLabel.minimumScaleFactor = 0.7
        udidLabel.text = "加载中..."
        
        // 添加复制按钮
        let copyButton = UIButton(type: .system)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemBlue
        copyButton.addTarget(self, action: #selector(copyUDIDButtonTapped), for: .touchUpInside)
        
        // 添加视图到容器
        udidContainerView.addSubview(titleLabel)
        udidContainerView.addSubview(udidLabel)
        udidContainerView.addSubview(copyButton)
        
        // 设置约束
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
        
        // 调整集合视图的内容边距，为设备ID显示区域腾出空间
        collectionView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 0, right: 0)
    }
    
    @objc private func copyUDIDButtonTapped() {
        // 复制设备ID到剪贴板
        let uuid = deviceUUID
        UIPasteboard.general.string = uuid
        
        // 显示复制成功提示
        let alert = UIAlertController(
            title: "已复制",
            message: "设备标识已复制到剪贴板",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // 初始化设备ID (替代旧的checkForStoredUDID方法)
    private func initializeDeviceID() {
        // 从KeyChain获取或创建UUID
        let uuid = KeychainUUID.getUUID()
        globalDeviceUUID = uuid
        
        // 更新UI显示
        updateUDIDDisplay(uuid)
        
        Debug.shared.log(message: "设备标识: \(uuid)")
        
        // 同时保存到UserDefaults以兼容旧代码
        UserDefaults.standard.set(uuid, forKey: "deviceUDID")
        
        // 同时也保存到ServerController使用的自定义键
        UserDefaults.standard.set(uuid, forKey: "custom_device_udid")
        UserDefaults.standard.synchronize()
        
        // 确保ServerController使用的是相同的UDID
        ServerController.shared.saveCustomUDID(uuid)
    }
    
    private func updateUDIDDisplay(_ uuid: String) {
        DispatchQueue.main.async { [weak self] in
            self?.udidLabel.text = uuid
        }
    }
    
    private func fetchAppData() {
        // 显示加载提示
        let loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用列表...", preferredStyle: .alert)
        present(loadingAlert, animated: true, completion: nil)
        
        // 使用ServerController获取应用列表
        ServerController.shared.getAppList { [weak self] serverApps, error in
            // 关闭加载提示
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true, completion: nil)
                
                if let error = error {
                    // 显示错误提示
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
                
                // 将ServerApp转换为AppData
                let convertedApps: [AppData] = serverApps.map { app in
                    // 检查本地是否已标记为已解锁
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

    private func checkDeviceAuthStatus(for app: AppData) {
        // 获取设备标识
        let uuid = deviceUUID
        guard !uuid.isEmpty else {
            // 失败时自动尝试重新生成
            initializeDeviceID()
            return
        }

        guard let encodedUUID = uuid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        // 构建API请求URL - 按照文档规范使用/api/client/check-udid格式
        let urlString = "\(baseURL)/check-udid?udid=\(encodedUUID)"
        guard let url = URL(string: urlString) else {
            return
        }
        
        Debug.shared.log(message: "检查设备授权状态，设备标识: \(uuid)")
        
        // 显示加载中提示
        let loadingAlert = UIAlertController(title: "检查中", message: "正在检查设备授权状态...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if let error = error {
                        self.handleDeviceCheckError(for: app, error: error)
                        return
                    }
                    
                    guard let data = data else {
                        self.promptUnlockCode(for: app)
                        return
                    }
                    
                    do {
                        let response = try JSONDecoder().decode(APIResponse<UDIDStatus>.self, from: data)
                        
                        if response.success {
                            if response.data.bound {
                                Debug.shared.log(message: "设备已授权，绑定数: \(response.data.bindings?.count ?? 0)")
                                
                                // 设备已绑定，直接获取应用详情并安装
                                // 保存本地解锁状态
                                UserDefaults.standard.set(true, forKey: "app_unlocked_\(app.id)")
                                UserDefaults.standard.synchronize()
                                
                                self.fetchAppDetails(for: app)
                            } else {
                                Debug.shared.log(message: "设备未授权，需要卡密验证")
                                self.promptUnlockCode(for: app)
                            }
                        } else {
                            Debug.shared.log(message: "授权检查失败: \(response.message ?? "未知错误")")
                            self.promptUnlockCode(for: app)
                        }
                    } catch {
                        Debug.shared.log(message: "授权数据解析错误: \(error.localizedDescription)")
                        self.promptUnlockCode(for: app)
                    }
                }
            }
        }.resume()
    }
    
    // 添加设备授权检查错误处理方法
    private func handleDeviceCheckError(for app: AppData, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            let errorMessage = error?.localizedDescription ?? "网络连接错误"
            Debug.shared.log(message: "设备授权检查失败: \(errorMessage)")
            
            // 显示错误提示并提供重试选项
            let alert = UIAlertController(
                title: "授权检查失败",
                message: "无法验证设备授权状态，请检查网络连接后重试。\n\n错误: \(errorMessage)",
                preferredStyle: .alert
            )
            
            // 重试选项
            alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
                self?.checkDeviceAuthStatus(for: app)
            })
            
            // 强制输入卡密选项
            alert.addAction(UIAlertAction(title: "输入卡密", style: .default) { [weak self] _ in
                self?.promptUnlockCode(for: app)
            })
            
            // 取消选项
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            
            self?.present(alert, animated: true)
        }
    }

    private func verifyUnlockCode(_ code: String, for app: AppData) {
        // 确保卡密不为空
        guard !code.isEmpty else {
            showError(title: "验证失败", message: "卡密不能为空")
            return
        }
        
        // 确保设备标识有效
        let deviceId = deviceUUID
        guard !deviceId.isEmpty else {
            showError(title: "验证失败", message: "无法获取设备标识，请重新启动应用")
            return
        }
        
        Debug.shared.log(message: "开始验证卡密: \(code) 用于应用: \(app.id), 设备: \(deviceId)")
        
        // 使用ServerController验证卡密
        ServerController.shared.verifyCard(cardKey: code, appId: app.id) { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                    // 验证成功，保存本地解锁状态
                    UserDefaults.standard.set(true, forKey: "app_unlocked_\(app.id)")
                    UserDefaults.standard.synchronize()
                    
                    Debug.shared.log(message: "卡密验证成功: \(app.name)")
                    
                    // 刷新服务器上的应用状态
                    ServerController.shared.refreshAppDetail(appId: app.id) { _, _ in
                        // 无论刷新成功与否，都继续安装流程
                    }
                    
                    // 检查响应中是否包含plist链接
                    if let responsePlist = message, responsePlist.contains("https://") && responsePlist.contains(".plist") {
                        // 显示成功消息
                        let alert = UIAlertController(
                            title: "验证成功",
                            message: "卡密验证成功，即将安装应用",
                            preferredStyle: .alert
                        )
                        
                        self?.present(alert, animated: true)
                        
                        // 短暂显示后关闭
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            alert.dismiss(animated: true) {
                                // 创建一个更新后的应用对象，使用验证响应中的plist
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
                                    plist: responsePlist,
                                    web_icon: app.web_icon,
                                    type: app.type,
                                    requires_key: app.requires_key,
                                    created_at: app.created_at,
                                    updated_at: app.updated_at,
                                    requiresUnlock: true,
                                    isUnlocked: true
                                )
                                
                                // 直接开始安装
                                self?.startInstallation(for: updatedAppData)
                            }
                        }
                    } else {
                        // 显示成功消息
                        let alert = UIAlertController(
                            title: "验证成功",
                            message: message ?? "卡密验证成功",
                            preferredStyle: .alert
                        )
                        
                        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                            // 在用户点击确定后，刷新应用详情
                            let refreshAlert = UIAlertController(title: "刷新中", message: "正在刷新应用信息...", preferredStyle: .alert)
                            self?.present(refreshAlert, animated: true)
                            
                            // 使用refreshAppDetail方法刷新应用绑定状态
                            ServerController.shared.refreshAppDetail(appId: app.id) { success, error in
                                DispatchQueue.main.async {
                                    refreshAlert.dismiss(animated: true)
                                    
                                    if success {
                                        // 显示短暂的成功提示
                                        let successAlert = UIAlertController(
                                            title: "解锁成功",
                                            message: "应用已解锁，即将开始安装",
                                            preferredStyle: .alert
                                        )
                                        self?.present(successAlert, animated: true)
                                        
                                        // 短暂显示后关闭
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            successAlert.dismiss(animated: true) {
                                                // 创建一个更新后的应用对象，标记为已解锁
                                                _ = app
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
                                                
                                                // 重新获取应用详情并继续安装
                                                self?.fetchAppDetails(for: updatedAppData)
                                            }
                                        }
                                    } else {
                                        // 显示刷新失败但继续获取应用详情
                                        let errorAlert = UIAlertController(
                                            title: "刷新失败",
                                            message: "应用详情刷新失败，但将尝试继续安装",
                                            preferredStyle: .alert
                                        )
                                        self?.present(errorAlert, animated: true)
                                        
                                        // 短暂显示后关闭
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            errorAlert.dismiss(animated: true) {
                                                // 创建一个更新后的应用对象，标记为已解锁
                                                _ = app
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
                                                
                                                // 尝试常规的获取应用详情
                                                self?.fetchAppDetails(for: updatedAppData)
                                            }
                                        }
                                    }
                                }
                            }
                        })
                    }
                } else {
                    // 验证失败处理
                    let errorMessage = message ?? "请检查卡密是否正确"
                    Debug.shared.log(message: "卡密验证失败: \(errorMessage)")
                    
                    // 显示失败消息
                    let alert = UIAlertController(
                        title: "验证失败",
                        message: errorMessage,
                        preferredStyle: .alert
                    )
                    
                    // 添加重试选项
                    alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
                        // 重新显示卡密输入框
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.promptUnlockCode(for: app)
                        }
                    })
                    
                    // 添加取消选项
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                    
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    // 处理安装应用请求
    private func handleInstall(for app: AppData) {
        // 首先确保有有效的设备标识
        if deviceUUID.isEmpty {
            // 设备标识缺失，提示用户获取
            let alert = UIAlertController(
                title: "需要设备标识",
                message: "安装应用需要获取设备标识，请点击\"生成设备标识\"按钮开始获取流程。\n\n这是确保您可以安装和使用应用的必要步骤。",
                preferredStyle: .alert
            )
            
            let getDeviceIDAction = UIAlertAction(title: "生成设备标识", style: .default) { [weak self] _ in
                self?.initializeDeviceID()
                
                // 标识生成后继续安装流程
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.handleInstall(for: app)
                }
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            alert.addAction(getDeviceIDAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion: nil)
            return
        }

        // 检查应用是否需要卡密 (requires_key = 1)
        if app.requires_key == 1 {
            Debug.shared.log(message: "应用需要卡密: \(app.name)")
            
            // 对于需要卡密的应用，先检查服务器授权状态，无论本地是否标记为已解锁
            checkDeviceAuthStatus(for: app)
        } else {
            // 免费应用，直接获取详情并安装
            fetchAppDetails(for: app)
        }
    }

    // 添加一个新方法，支持已显示加载提示的情况
    private func fetchAppDetails(for app: AppData, loadingAlertShown: Bool = false, existingAlert: UIAlertController? = nil) {
        // 显示加载提示（如果尚未显示）
        var loadingAlert = existingAlert
        if !loadingAlertShown {
            loadingAlert = UIAlertController(title: "加载中", message: "正在获取应用信息...", preferredStyle: .alert)
            present(loadingAlert!, animated: true, completion: nil)
        }
        
        // 使用ServerController获取应用详情
        ServerController.shared.getAppDetail(appId: app.id) { [weak self] appDetail, error in
            DispatchQueue.main.async {
                // 关闭加载提示
                loadingAlert?.dismiss(animated: true) {
                    if let error = error {
                        // 检查plist是否已有，如果有则可以直接使用
                        if let plist = app.plist, !plist.isEmpty {
                            // 如果本地已标记为已解锁，尝试设置解锁状态
                            let isLocallyUnlocked = UserDefaults.standard.bool(forKey: "app_unlocked_\(app.id)")
                            let updatedApp = AppData(
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
                                plist: plist,
                                web_icon: app.web_icon,
                                type: app.type,
                                requires_key: app.requires_key,
                                created_at: app.created_at,
                                updated_at: app.updated_at,
                                requiresUnlock: app.requires_key == 1,
                                isUnlocked: isLocallyUnlocked
                            )
                            
                            // 短暂延迟后开始安装
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self?.startInstallation(for: updatedApp)
                            }
                            return
                        }
                        
                        // 检查应用是否需要卡密
                        if app.requiresKey {
                            self?.checkDeviceAuthStatus(for: app)
                        } else {
                            // 显示错误提示
                            let errorAlert = UIAlertController(
                                title: "获取应用信息失败",
                                message: "无法获取应用详细信息，请稍后再试。\n错误: \(error)",
                                preferredStyle: .alert
                            )
                            
                            // 添加重试按钮
                            errorAlert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
                                self?.fetchAppDetails(for: app)
                            })
                            
                            errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                            
                            guard let self = self, self.isViewLoaded && self.view.window != nil else { return }
                            self.present(errorAlert, animated: true)
                        }
                        return
                    }
                    
                    guard let appDetail = appDetail else {
                        // 如果是需要卡密的应用，检查授权状态
                        if app.requiresKey {
                            self?.checkDeviceAuthStatus(for: app)
                        } else {
                            let errorAlert = UIAlertController(
                                title: "获取应用信息失败",
                                message: "服务器未返回应用详情",
                                preferredStyle: .alert
                            )
                            errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                            self?.present(errorAlert, animated: true)
                        }
                        return
                    }
                    
                    // 从服务器获取的应用详情
                    
                    // 同步服务器返回的解锁状态到本地
                    if appDetail.isUnlocked {
                        UserDefaults.standard.set(true, forKey: "app_unlocked_\(appDetail.id)")
                        UserDefaults.standard.synchronize()
                    }
                    
                    // 检查应用是否有plist字段
                    if let plist = appDetail.plist, !plist.isEmpty {
                        // 构建完整的应用对象，包含从服务器获取的解锁状态
                        let updatedApp = AppData(
                            id: appDetail.id,
                            name: appDetail.name,
                            date: app.date,
                            size: app.size,
                            channel: app.channel,
                            build: app.build,
                            version: appDetail.version,
                            identifier: app.identifier,
                            pkg: appDetail.pkg,
                            icon: appDetail.icon,
                            plist: plist,
                            web_icon: app.web_icon,
                            type: app.type,
                            requires_key: appDetail.requiresKey ? 1 : 0,
                            created_at: app.created_at,
                            updated_at: app.updated_at,
                            requiresUnlock: appDetail.requiresUnlock,
                            isUnlocked: appDetail.isUnlocked || UserDefaults.standard.bool(forKey: "app_unlocked_\(appDetail.id)")
                        )
                        
                        // 判断应用是否需要卡密且未解锁
                        if (updatedApp.requiresUnlock ?? false) && !(updatedApp.isUnlocked ?? false) {
                            // 检查设备绑定状态
                            self?.checkDeviceAuthStatus(for: updatedApp)
                        } else {
                            // 应用不需要卡密或已解锁，直接安装
                            self?.startInstallation(for: updatedApp)
                        }
                    } else {
                        // 如果应用需要卡密验证且未解锁
                        if appDetail.requiresUnlock && !appDetail.isUnlocked {
                            // 检查设备绑定状态
                            
                            // 创建一个有相同ID的AppData对象用于验证卡密
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
                            
                            self?.checkDeviceAuthStatus(for: tempApp)
                        } else {
                            // 显示无法安装提示
                            let noPlAlert = UIAlertController(
                                title: "无法安装",
                                message: "应用缺少安装信息",
                                preferredStyle: .alert
                            )
                            noPlAlert.addAction(UIAlertAction(title: "确定", style: .default))
                            self?.present(noPlAlert, animated: true)
                        }
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

    // 设置每个卡片的大小（宽度和高度）
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 30 // 减去左右的间距
        let height: CGFloat = 90 // 固定每个卡片的高度为 50
        return CGSize(width: width, height: height)
    }

    // 添加一个方法来处理服务器返回的plist链接，格式可能是加密数据
    private func processPlistLink(_ plistLink: String) -> String {
        // 1. 如果链接是直接的URL，无需处理
        if plistLink.lowercased().hasPrefix("http") {
            return plistLink
        }
        
        // 2. 如果链接是相对路径，添加基础URL
        if plistLink.hasPrefix("/") {
            // 检查是否是API plist格式的路径（检查格式：/api/plist/<IV>/<加密数据>）
            if plistLink.hasPrefix("/api/plist/") {
                let components = plistLink.components(separatedBy: "/")
                if components.count >= 5 {
                    // 应该有格式：["", "api", "plist", "<IV>", "<加密数据>"]
                    let fullURL = AppSecurityManager.shared.buildAPIURL(path: plistLink)
                    return fullURL
                }
            }
            
            // 普通相对路径
            let fullURL = AppSecurityManager.shared.buildAPIURL(path: plistLink)
            return fullURL
        }
        
        // 3. 如果链接可能是加密数据，尝试解密
        do {
            // 先尝试解析为JSON
            if let data = plistLink.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // 检查是否包含加密所需的IV和data字段
                if let iv = json["iv"] as? String,
                   let encryptedData = json["data"] as? String {
                    
                    if let decryptedURL = AppSecurityManager.shared.decryptString(encryptedData: encryptedData, iv: iv) {
                        return decryptedURL
                    }
                }
            }
        } catch {
            // 处理解析错误
        }
        
        // 4. 如果链接看起来像是从特定API返回的加密链接格式
        if plistLink.contains("/api/plist/") && plistLink.contains("/") {
            // 这可能是已经格式化好的加密plist链接
            let fullURL = plistLink.hasPrefix("http") ? plistLink : AppSecurityManager.shared.buildAPIURL(path: plistLink)
            return fullURL
        }
        
        // 5. 尝试从链接中提取IV和加密数据（如果格式是：<IV>/<加密数据>）
        let components = plistLink.components(separatedBy: "/")
        if components.count == 2 {
            let possibleIV = components[0]
            let possibleData = components[1]
            
            let (valid, _) = CryptoUtils.shared.validateFormat(encryptedData: possibleData, iv: possibleIV)
            if valid {
                let apiPath = "/api/plist/\(possibleIV)/\(possibleData)"
                let fullURL = AppSecurityManager.shared.buildAPIURL(path: apiPath)
                return fullURL
            }
        }
        
        // 6. 如果以上都不匹配，直接返回原始链接
        return plistLink
    }
    
    // 新增：加密安装URL的方法
    private func encryptInstallURL(plistURL: String) -> [String: String]? {
        // 使用安全管理器加密安装URL
        return AppSecurityManager.shared.buildAndEncryptInstallURL(plistURL: plistURL)
    }
    
    // 添加一个方法来验证plist URL
    private func verifyPlistURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // 只获取头信息，不下载内容
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 此处不再需要验证处理，简化为空实现
        }.resume()
    }
    
    // 新增：解密并打开安装URL的方法
    private func decryptAndOpenInstallURL(encryptedData: [String: String]) {
        guard let iv = encryptedData["iv"], 
              let data = encryptedData["data"],
              let decryptedURL = AppSecurityManager.shared.decryptString(encryptedData: data, iv: iv) else {
            showError(title: "安装失败", message: "无法解析安装信息")
            return
        }
        
        // 使用现有的安全方法打开解密后的URL
        safelyOpenInstallURL(decryptedURL)
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
        
        // 使用新的方法处理plist链接
        let finalPlistURL = processPlistLink(plist)
        
        // 确保URL编码正确
        let encodedPlistURL = finalPlistURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? finalPlistURL
        
        // 验证plist URL
        verifyPlistURL(encodedPlistURL)
        
        // 加密安装URL
        guard let encryptedInstallURL = encryptInstallURL(plistURL: encodedPlistURL) else {
            showError(title: "安装失败", message: "无法准备安装信息")
            return
        }
        
        // 判断应用是否可以直接安装
        // 免费应用(requires_key=0)或已解锁的应用(isUnlocked=true)都可以直接安装
        if app.requires_key == 0 || ((app.requiresUnlock ?? false) && (app.isUnlocked ?? false)) {
            // 免费或已解锁的应用，直接安装
            // 使用解密并打开URL的方法
            decryptAndOpenInstallURL(encryptedData: encryptedInstallURL)
        } else {
            // 需要卡密且未解锁的应用，显示确认对话框
            let alert = UIAlertController(
                title: "确认安装",
                message: "是否安装 \(app.name)？\n\n版本: \(app.version)",
                preferredStyle: .alert
            )

            let installAction = UIAlertAction(title: "安装", style: .default) { [weak self] _ in
                // 使用解密并打开URL的方法
                self?.decryptAndOpenInstallURL(encryptedData: encryptedInstallURL)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            alert.addAction(installAction)
            alert.addAction(cancelAction)

            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // 添加显示UDID帮助指南的方法
    @objc private func showUDIDHelpGuide() {
        let helpVC = UIViewController()
        helpVC.title = "设备标识信息"
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
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "关于设备标识"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        
        // 介绍
        let introLabel = UILabel()
        introLabel.text = "设备标识是应用存储在设备中的唯一识别码，用于标识您的设备。此标识符保存在设备的钥匙串(Keychain)中，即使卸载应用后重新安装也会保持不变。"
        introLabel.font = UIFont.systemFont(ofSize: 16)
        introLabel.numberOfLines = 0
        
        // 使用说明
        let usageLabel = UILabel()
        usageLabel.text = "使用说明:"
        usageLabel.font = UIFont.boldSystemFont(ofSize: 18)
        usageLabel.numberOfLines = 0
        
        // 步骤1
        let step1Label = createStepLabel(number: 1, text: "设备标识已自动生成并显示在应用顶部")
        
        // 步骤2
        let step2Label = createStepLabel(number: 2, text: "您可以点击复制按钮复制此标识符")
        
        // 步骤3
        let step3Label = createStepLabel(number: 3, text: "安装应用时系统会自动使用此标识符验证您的设备")
        
        // 注意事项
        let noteLabel = UILabel()
        noteLabel.text = "注意：此标识符仅在当前设备上有效，不会跨设备共享，也不会被用于跟踪用户。"
        noteLabel.font = UIFont.italicSystemFont(ofSize: 16)
        noteLabel.textColor = .systemGray
        noteLabel.numberOfLines = 0
        
        // 显示当前标识符
        let currentUUIDLabel = UILabel()
        currentUUIDLabel.text = "当前设备标识: \n\(deviceUUID)"
        currentUUIDLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        currentUUIDLabel.textColor = .systemBlue
        currentUUIDLabel.numberOfLines = 0
        currentUUIDLabel.textAlignment = .center
        currentUUIDLabel.backgroundColor = .systemGray6
        currentUUIDLabel.layer.cornerRadius = 8
        currentUUIDLabel.layer.masksToBounds = true
        
        // 使用容器视图而不是直接设置padding属性
        let uuidContainer = UIView()
        uuidContainer.backgroundColor = .systemGray6
        uuidContainer.layer.cornerRadius = 8
        uuidContainer.addSubview(currentUUIDLabel)
        currentUUIDLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            currentUUIDLabel.topAnchor.constraint(equalTo: uuidContainer.topAnchor, constant: 10),
            currentUUIDLabel.leadingAnchor.constraint(equalTo: uuidContainer.leadingAnchor, constant: 10),
            currentUUIDLabel.trailingAnchor.constraint(equalTo: uuidContainer.trailingAnchor, constant: -10),
            currentUUIDLabel.bottomAnchor.constraint(equalTo: uuidContainer.bottomAnchor, constant: -10)
        ])
        
        // 添加刷新按钮
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("刷新设备标识", for: .normal)
        refreshButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        refreshButton.backgroundColor = UIColor.tintColor
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.layer.cornerRadius = 10
        
        // 使用更现代的方式设置按钮内边距
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            config.baseBackgroundColor = UIColor.tintColor
            config.baseForegroundColor = .white
            refreshButton.configuration = config
        } else {
            refreshButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        
        refreshButton.addTarget(self, action: #selector(getUDIDButtonTapped), for: .touchUpInside)
        
        // 添加所有视图到堆栈
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(introLabel)
        stackView.addArrangedSubview(usageLabel)
        stackView.addArrangedSubview(step1Label)
        stackView.addArrangedSubview(step2Label)
        stackView.addArrangedSubview(step3Label)
        stackView.addArrangedSubview(noteLabel)
        stackView.addArrangedSubview(uuidContainer)
        stackView.addArrangedSubview(refreshButton)
        
        // 调整堆栈视图内元素宽度
        for view in stackView.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        // 居中显示按钮
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true
        
        navigationController?.pushViewController(helpVC, animated: true)
    }

    // 创建步骤标签的辅助方法
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

    // 添加这两个设置方法
    private func setupViewModel() {
        // 已有的ViewModel初始化代码，如果有的话
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .systemBackground
        collectionView.register(AppCell.self, forCellWithReuseIdentifier: "AppCell")
    }

    private func extractUDID(from urlString: String) -> String? {
        // 检查URL是否包含udid部分
        if urlString.contains("/udid/") {
            // 分割URL获取UDID部分
            let components = urlString.components(separatedBy: "/udid/")
            if components.count > 1 {
                // 提取UDID（可能需要进一步清理）
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func promptUnlockCode(for app: AppData) {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.promptUnlockCode(for: app)
            }
            return
        }
        
        // 确保视图已加载到视图层次结构中
        guard isViewLoaded && view.window != nil else {
            // 视图未加载到窗口层次结构，延迟执行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.promptUnlockCode(for: app)
            }
            return
        }
        
        // 检查当前是否已有弹窗显示
        if let presentedVC = self.presentedViewController {
            // 先关闭当前弹窗，然后再显示卡密输入框
            presentedVC.dismiss(animated: false) { [weak self] in
                self?.createAndShowUnlockAlert(for: app)
            }
        } else {
            createAndShowUnlockAlert(for: app)
        }
    }

    // 新增方法，将原有弹窗创建逻辑分离
    private func createAndShowUnlockAlert(for app: AppData) {
        // 创建卡密输入对话框
        let alert = UIAlertController(
            title: "安装",
            message: "应用「\(app.name)」需要卡密才能安装\n请输入有效的卡密继续",
            preferredStyle: .alert
        )
        
        // 添加文本输入框
        alert.addTextField { textField in
            textField.placeholder = "请输入卡密"
            textField.clearButtonMode = .whileEditing
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
        }
        
        // 添加确认按钮
        let confirmAction = UIAlertAction(title: "安装", style: .default) { [weak self, weak alert] _ in
            guard let unlockCode = alert?.textFields?.first?.text, !unlockCode.isEmpty else {
                // 卡密为空，显示错误提示
                let errorAlert = UIAlertController(
                    title: "错误",
                    message: "卡密不能为空",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "重试", style: .default) { _ in
                    // 重新显示卡密输入框
                    self?.promptUnlockCode(for: app)
                })
                self?.present(errorAlert, animated: true)
                return
            }
            
            // 显示验证中提示
            let verifyingAlert = UIAlertController(
                title: "验证中",
                message: "正在验证卡密，请稍候...",
                preferredStyle: .alert
            )
            self?.present(verifyingAlert, animated: true)
            
            // 验证卡密
            self?.verifyUnlockCode(unlockCode, for: app)
            
            // 短暂延迟后关闭"验证中"提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                verifyingAlert.dismiss(animated: true)
            }
        }
        
        // 添加取消按钮
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        
        // 添加按钮到对话框
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        // 确保在主线程上显示对话框
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

    // 打开Safari安装描述文件
    @objc private func getUDIDButtonTapped() {
        // 不再调用showUDIDProfileAlert，直接使用KeychainUUID获取设备标识
        initializeDeviceID()
        
        // 显示成功提示
        let alert = UIAlertController(
            title: "已更新",
            message: "设备标识已更新并保存",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // 处理JSON对象为AppData
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
            
            // 获取其他可选字段
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
            
            // 创建并返回AppData对象
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
    
    // 方法用于直接处理应用详情
    private func handleAppJson(_ jsonString: String) {
        if let app = parseAppData(jsonString) {
            // 应用可以安装，并获取到plist
            if let plist = app.plist {
                // 添加加载提示
                let loadingAlert = UIAlertController(title: "处理中", message: "正在准备安装...", preferredStyle: .alert)
                present(loadingAlert, animated: true) {
                    // 在背景线程处理，避免阻塞UI
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        // 短暂延迟，模拟处理时间
                        Thread.sleep(forTimeInterval: 0.5)
                        
                        DispatchQueue.main.async {
                            loadingAlert.dismiss(animated: true) {
                                // 如果是免费或已解锁应用，自动处理安装
                                let isReadyForDirectInstall = app.requires_key == 0 || ((app.requiresUnlock ?? false) && (app.isUnlocked ?? false))
                                
                                if isReadyForDirectInstall {
                                    self?.startInstallation(for: app)
                                } else {
                                    // 需要确认的应用，显示确认对话框
                                    let confirmAlert = UIAlertController(
                                        title: "确认安装",
                                        message: "是否安装 \(app.name) 版本 \(app.version)？",
                                        preferredStyle: .alert
                                    )
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "安装", style: .default) { _ in
                                        self?.checkDeviceAuthStatus(for: app)
                                    })
                                    
                                    confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel))
                                    
                                    self?.present(confirmAlert, animated: true)
                                }
                            }
                        }
                    }
                }
            } else {
                print("应用无法安装：缺少安装信息")
                let alert = UIAlertController(
                    title: "无法安装",
                    message: "此应用暂时无法安装，请稍后再试",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        } else {
            print("应用数据解析失败")
            let alert = UIAlertController(
                title: "应用解析失败",
                message: "无法解析应用数据，请稍后再试",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    // 添加一个选项，允许用户直接输入JSON数据
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
    
    // 显示错误信息
    private func showError(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // 添加新方法来分段处理和验证长URL
    private func safelyOpenInstallURL(_ urlString: String) {
        // 尝试创建和打开URL
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: { success in
                    if !success {
                        // 尝试分析失败原因
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

    // 尝试分析URL打开失败的原因
    private func analyzeURLOpenFailure(_ urlString: String) {
        // 检查是否是常见的问题
        if urlString.contains(" ") {
            let trimmedURL = urlString.replacingOccurrences(of: " ", with: "%20")
            if let url = URL(string: trimmedURL) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        
        // 显示错误提示
        showURLErrorAlert(urlString)
    }

    // 处理可能无效的URL
    private func handlePotentiallyInvalidURL(_ urlString: String) -> String {
        // 替换特殊字符
        var modifiedURL = urlString
        let problematicCharacters = [" ", "<", ">", "#", "%", "{", "}", "|", "\\", "^", "~", "[", "]", "`"]
        
        for char in problematicCharacters {
            modifiedURL = modifiedURL.replacingOccurrences(of: char, with: urlEncodeCharacter(char))
        }
        
        return modifiedURL
    }

    // URL编码单个字符
    private func urlEncodeCharacter(_ character: String) -> String {
        return character.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? character
    }

    // 显示URL错误提示
    private func showURLErrorAlert(_ urlString: String) {
        let alertMessage = """
        操作无法完成，可能原因：
        1. 链接配置不正确
        2. 数据格式错误
        3. 系统安全限制
        
        请联系开发者解决此问题。
        """
        
        let alert = UIAlertController(
            title: "安装失败",
            message: alertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "复制链接", style: .default) { _ in
            UIPasteboard.general.string = urlString
        })
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        present(alert, animated: true)
    }

    // 添加一个调试方法，用于检查应用解锁状态
    private func checkAppUnlockStatus(for appId: String) {
        // 显示加载提示
        let loadingAlert = UIAlertController(title: "检查中", message: "正在检查应用解锁状态...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 使用ServerController获取应用详情
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
                
                // 显示应用状态
                let statusMessage = """
                应用名称: \(appDetail.name)
                版本: \(appDetail.version)
                是否需要解锁: \(appDetail.requiresUnlock ? "是" : "否")
                是否已解锁: \(appDetail.isUnlocked ? "是" : "否")
                UDID: \(globalDeviceUUID ?? "未知")
                """
                
                let statusAlert = UIAlertController(
                    title: "应用状态",
                    message: statusMessage,
                    preferredStyle: .alert
                )
                
                // 添加尝试安装按钮
                statusAlert.addAction(UIAlertAction(title: "尝试安装", style: .default) { [weak self] _ in
                    if let plist = appDetail.plist {
                        // 创建一个新的AppData对象进行安装
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
                
                // 添加输入卡密按钮
                statusAlert.addAction(UIAlertAction(title: "输入卡密", style: .default) { [weak self] _ in
                    // 创建临时应用对象
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

    // 添加处理卡密验证结果的方法
    @objc private func handleCardVerificationResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let success = userInfo["success"] as? Bool,
              let appId = userInfo["appId"] as? String else {
            return
        }
        
        if success {
            // 验证成功，尝试获取应用详情并安装
            // 创建一个临时应用对象
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
            
            // 获取最新的应用详情
            fetchAppDetails(for: tempApp)
        }
    }
}

// 自定义 Cell
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
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.layer.cornerRadius = 15
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowRadius = 5

        // 配置UI元素
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.layer.cornerRadius = 35 // 一半的设置宽度
        appIcon.clipsToBounds = true
        
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .darkGray
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        versionLabel.font = UIFont.systemFont(ofSize: 14, weight: .light)
        versionLabel.textColor = .lightGray
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        installButton.backgroundColor = .systemBlue
        installButton.layer.cornerRadius = 10
        installButton.setTitle("安装", for: .normal)
        installButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        installButton.tintColor = .white
        installButton.translatesAutoresizingMaskIntoConstraints = false
        installButton.addTarget(self, action: #selector(installTapped), for: .touchUpInside)
        
        // 设置限免标签
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
        freeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加视图
        contentView.addSubview(appIcon)
        contentView.addSubview(nameLabel)
        contentView.addSubview(versionLabel)
        contentView.addSubview(installButton)
        contentView.addSubview(freeLabel)
        
        // 设置布局约束
        NSLayoutConstraint.activate([
            appIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            appIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 70),
            appIcon.heightAnchor.constraint(equalToConstant: 70),
            
            nameLabel.leadingAnchor.constraint(equalTo: appIcon.trailingAnchor, constant: 15),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: installButton.leadingAnchor, constant: -10),
            
            versionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            versionLabel.trailingAnchor.constraint(lessThanOrEqualTo: installButton.leadingAnchor, constant: -10),
            
            installButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            installButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            installButton.widthAnchor.constraint(equalToConstant: 80),
            installButton.heightAnchor.constraint(equalToConstant: 40),
            
            freeLabel.topAnchor.constraint(equalTo: appIcon.topAnchor),
            freeLabel.leadingAnchor.constraint(equalTo: appIcon.leadingAnchor, constant: -5),
            freeLabel.widthAnchor.constraint(equalToConstant: 40),
            freeLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with app: StoreCollectionViewController.AppData) {
        nameLabel.text = app.name
        
        // 检查本地是否已解锁
        let isUnlockedLocally = UserDefaults.standard.bool(forKey: "app_unlocked_\(app.id)")
        
        // 判断应用状态
        if app.requires_key == 0 {
            // 完全免费应用
            isFreemiumApp = true
            // 隐藏标签
            freeLabel.isHidden = true
            
            // 针对限免应用，在版本号旁边显示状态，但去掉"限免安装"文字
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemGreen
            
            // 给限免应用的安装按钮设置不同的样式
            installButton.backgroundColor = .systemGreen
            installButton.setTitle("免费安装", for: .normal)
        } else if (app.requiresUnlock ?? false) && ((app.isUnlocked ?? false) || isUnlockedLocally) {
            // 已解锁的付费应用
            isFreemiumApp = true  // 使用相同的动画效果
            // 隐藏标签
            freeLabel.isHidden = true
            
            // 显示版本号，但去掉"已解锁"文字
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemBlue
            
            // 设置按钮样式
            installButton.backgroundColor = .systemBlue
            installButton.setTitle("安装", for: .normal)
        } else {
            // 未解锁的付费应用
            isFreemiumApp = false
            // 隐藏标签
            freeLabel.isHidden = true
            
            // 显示版本号，但去掉"需要卡密"文字
            versionLabel.text = "版本 \(app.version)"
            versionLabel.textColor = .systemOrange
            
            // 设置未解锁付费应用的安装按钮样式
            installButton.backgroundColor = .systemOrange
            installButton.setTitle("安装", for: .normal)
        }
        
        if let url = URL(string: app.icon) {
            loadImage(from: url, into: appIcon)
        }
    }

    @objc private func installTapped() {
        // 添加按钮点击视觉反馈，特别是对免费应用
        if isFreemiumApp {
            // 免费或已解锁应用，显示加载效果
            UIView.animate(withDuration: 0.15, animations: {
                self.installButton.alpha = 0.6
                self.installButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.installButton.setTitle("处理中...", for: .normal)
            }, completion: { _ in
                // 调用安装回调
                self.onInstallTapped?()
                
                // 延迟恢复按钮状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    UIView.animate(withDuration: 0.2) {
                        self.installButton.alpha = 1.0
                        self.installButton.transform = .identity
                        // 恢复原始文本
                        if self.installButton.backgroundColor == .systemGreen {
                            self.installButton.setTitle("免费安装", for: .normal)
                        } else {
                            self.installButton.setTitle("安装", for: .normal)
                        }
                    }
                }
            })
        } else {
            // 普通应用，简单的视觉反馈
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
