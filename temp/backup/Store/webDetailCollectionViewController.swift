//
//  webDetailCollectionViewController.swift
//  mantou
//
//  Created by mantou on 2025/3/30.
//

import UIKit
@preconcurrency import WebKit

class WebDetailCollectionViewController: UIViewController {
    
    // MARK: - 属性
    
    var websiteURL: String?
    var websiteName: String?
    
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var progressObservation: NSKeyValueObservation?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let backButton = UIButton(type: .system)
    
    // MARK: - 生命周期方法
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureNavBar()
        setupBackButton()
        loadWebsite()
    }
    
    deinit {
        progressObservation?.invalidate()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 设置WebView - 优化配置以确保网页正确显示
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.preferences.javaScriptEnabled = true
        
        // 适配移动端和PC网页
        let userAgentString = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webConfiguration.applicationNameForUserAgent = userAgentString
        
        // 配置WebView及其frame
        webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self // 添加UI代理以处理alert等
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // 添加WebView
        view.addSubview(webView)
        
        // 设置进度条
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        view.addSubview(progressView)
        
        // 设置加载指示器
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemBlue
        view.addSubview(activityIndicator)
        
        // 设置约束
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 观察进度变化
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            self.progressView.progress = Float(webView.estimatedProgress)
            
            // 当加载完成时隐藏进度条
            if webView.estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.alpha = 0
                }, completion: { _ in
                    self.progressView.progress = 0
                })
            } else {
                self.progressView.alpha = 1
            }
        }
    }
    
    private func configureNavBar() {
        title = websiteName ?? "网站"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // 添加导航按钮
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshWebView))
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareWebsite))
        navigationItem.rightBarButtonItems = [shareButton, refreshButton]
        
        // 添加后退和前进按钮
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(goBack))
        let forwardButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(goForward))
        
        navigationItem.leftBarButtonItems = [backButton, forwardButton]
        
        // 设置导航栏返回按钮
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "返回", style: .plain, target: nil, action: nil)
    }
    
    private func setupBackButton() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        backButton.tintColor = .white
        backButton.layer.cornerRadius = 25
        backButton.layer.shadowColor = UIColor.black.cgColor
        backButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        backButton.layer.shadowRadius = 4
        backButton.layer.shadowOpacity = 0.3
        backButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        backButton.addTarget(self, action: #selector(closeWebView), for: .touchUpInside)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - 加载网页
    
    private func loadWebsite() {
        guard let urlString = websiteURL, let url = URL(string: urlString) else {
            showErrorAlert(message: "无效的URL")
            return
        }
        
        let request = URLRequest(url: url)
        activityIndicator.startAnimating()
        webView.load(request)
    }
    
    // MARK: - 操作方法
    
    @objc private func refreshWebView() {
        webView.reload()
    }
    
    @objc private func shareWebsite() {
        guard let urlString = websiteURL, let url = URL(string: urlString) else { return }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
    
    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    @objc private func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    @objc private func closeWebView() {
        navigationController?.popViewController(animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension WebDetailCollectionViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        
        // 更新导航按钮状态
        navigationItem.leftBarButtonItems?[0].isEnabled = webView.canGoBack
        navigationItem.leftBarButtonItems?[1].isEnabled = webView.canGoForward
        
        // 最小化JavaScript干预，只添加基本的viewport设置
        let viewport = """
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
        }
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
        """
        webView.evaluateJavaScript(viewport, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showErrorAlert(message: "加载失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showErrorAlert(message: "加载失败: \(error.localizedDescription)")
    }
    
    // 处理新窗口打开请求
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - WKUIDelegate
extension WebDetailCollectionViewController: WKUIDelegate {
    // 处理alert弹窗
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler()
        }))
        present(alertController, animated: true)
    }
    
    // 处理confirm弹窗
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(true)
        }))
        present(alertController, animated: true)
    }
    
    // 处理prompt弹窗
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completionHandler(nil)
        }))
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(alertController.textFields?.first?.text)
        }))
        present(alertController, animated: true)
    }
}

