
import UIKit
@preconcurrency import WebKit

class ContentDetailViewController: UIViewController {
    
    
    var websiteURL: String?
    var websiteName: String?
    
    private let allowedDomains: [String] = [
        "cloudmantoub.online",
        "example.com",
        "trusteddomain.com"
    ]
    
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var progressObservation: NSKeyValueObservation?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let backButton = UIButton(type: .system)
    
    private let blockedScripts = [
        "window.open",
        "document.location",
        "location.href"
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureNavBar()
        setupBackButton()
        loadContent()
    }
    
    deinit {
        progressObservation?.invalidate()
    }
    
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = [.all]
        
        let contentController = WKUserContentController()
        
        let csp = """
        var meta = document.createElement('meta');
        meta.httpEquiv = 'Content-Security-Policy';
        meta.content = "default-src 'self' * data:; script-src 'self' 'unsafe-inline' 'unsafe-eval' *; style-src 'self' 'unsafe-inline' *";
        document.head.appendChild(meta);
        """
        
        let cspScript = WKUserScript(
            source: csp,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(cspScript)
        
        let blockScript = """
        (function() {
            window.realWindowOpen = window.open;
            window.open = function(url, name, features) {
                if (url && (url.startsWith('https://cloudmantoub.online') || url.startsWith('https://example.com'))) {
                    return window.realWindowOpen(url, name, features);
                }
                console.log('Blocked window.open for: ' + url);
                return null;
            };
        })();
        """
        
        let blockScriptObj = WKUserScript(
            source: blockScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(blockScriptObj)
        
        webConfiguration.userContentController = contentController
        
        let userAgentString = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webConfiguration.applicationNameForUserAgent = userAgentString
        
        webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self // 添加UI代理以处理alert等
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        view.addSubview(webView)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        view.addSubview(progressView)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemBlue
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            self.progressView.progress = Float(webView.estimatedProgress)
            
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
        title = websiteName ?? "内容详情"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshContent))
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareContent))
        navigationItem.rightBarButtonItems = [shareButton, refreshButton]
        
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(goBack))
        let forwardButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(goForward))
        
        navigationItem.leftBarButtonItems = [backButton, forwardButton]
        
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
        backButton.addTarget(self, action: #selector(closeContent), for: .touchUpInside)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    
    private func loadContent() {
        guard let urlString = websiteURL, let url = URL(string: urlString) else {
            showErrorAlert(message: "无效的URL")
            return
        }
        
        if !isURLAllowed(url) {
            showErrorAlert(message: "出于安全考虑，不允许访问此域名")
            return
        }
        
        let request = URLRequest(url: url)
        activityIndicator.startAnimating()
        webView.load(request)
    }
    
    private func isURLAllowed(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        
        for domain in allowedDomains {
            if host.contains(domain) {
                return true
            }
        }
        
        let defaultAllowedURLs = [
            "cloudmantoub.online",
            "uni.cloudmantoub.online"
        ]
        
        for allowedURL in defaultAllowedURLs {
            if host.contains(allowedURL) {
                return true
            }
        }
        
        return false
    }
    
    
    @objc private func refreshContent() {
        webView.reload()
    }
    
    @objc private func shareContent() {
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
    
    @objc private func closeContent() {
        navigationController?.popViewController(animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}


extension ContentDetailViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if isURLAllowed(url) {
                decisionHandler(.allow)
            } else {
                showErrorAlert(message: "出于安全考虑，不允许访问此域名")
                decisionHandler(.cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        
        navigationItem.leftBarButtonItems?[0].isEnabled = webView.canGoBack
        navigationItem.leftBarButtonItems?[1].isEnabled = webView.canGoForward
        
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
        
        let contentEnhancement = """
        (function() {
            if (!document.getElementById('appflex-content-style')) {
                var style = document.createElement('style');
                style.id = 'appflex-content-style';
                style.textContent = `
                    
                    body { 
                        font-size: 16px; 
                        line-height: 1.6;
                        color: #333;
                    }
                    
                    a { 
                        color: #0066cc; 
                        text-decoration: none; 
                    }
                    
                    img { 
                        max-width: 100%; 
                        height: auto; 
                        display: block; 
                        margin: 10px auto; 
                    }
                    
                    article, .content, main, .main { 
                        padding: 0 10px; 
                    }
                    
                    @media (prefers-color-scheme: dark) {
                        body { 
                            color: #eee; 
                            background-color: #222; 
                        }
                        a { 
                            color: #66b3ff; 
                        }
                    }
                `;
                document.head.appendChild(style);
                
                document.documentElement.classList.add('appflex-enhanced');
            }
        })();
        """
        webView.evaluateJavaScript(contentEnhancement, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showErrorAlert(message: "加载失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showErrorAlert(message: "加载失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, isURLAllowed(url) {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
        }
        return nil
    }
}

extension ContentDetailViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler()
        }))
        present(alertController, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(true)
        }))
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        present(alertController, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(alertController.textFields?.first?.text)
        }))
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completionHandler(nil)
        }))
        present(alertController, animated: true)
    }
} 
