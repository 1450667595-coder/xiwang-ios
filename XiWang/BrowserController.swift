import UIKit
import WebKit

final class BrowserController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKDownloadDelegate {
    private let home = NavigationPolicy.home
    private var web: WKWebView!
    private let loading = UIActivityIndicatorView(style: .large)
    private let retry = UIButton(type: .system)
    private var downloads: [ObjectIdentifier: URL] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.77, green: 0.86, blue: 0.93, alpha: 1)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        if let url = Bundle.main.url(forResource: "downloads", withExtension: "js"), let script = try? String(contentsOf: url, encoding: .utf8) {
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        configuration.userContentController.add(WeakDownloadHandler(self), name: "xiwangDownload")
        web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.accessibilityIdentifier = "original-interface"
        web.isOpaque = false
        web.backgroundColor = view.backgroundColor
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor), web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.hidesWhenStopped = true
        view.addSubview(loading)
        NSLayoutConstraint.activate([loading.centerXAnchor.constraint(equalTo: view.centerXAnchor), loading.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        var glass = UIButton.Configuration.glass(); glass.title = "网络暂时不可用，点击重新连接"; glass.contentInsets = NSDirectionalEdgeInsets(top:14,leading:18,bottom:14,trailing:18); retry.configuration = glass
        retry.backgroundColor = .clear
        retry.layer.cornerRadius = 20
        
        retry.accessibilityIdentifier = "retryConnection"
        retry.translatesAutoresizingMaskIntoConstraints = false
        retry.addTarget(self, action: #selector(reconnect), for: .touchUpInside)
        retry.isHidden = true
        view.addSubview(retry)
        NSLayoutConstraint.activate([retry.centerXAnchor.constraint(equalTo: view.centerXAnchor), retry.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)])
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
        reconnect()
    }

    private func trusted(_ url: URL?) -> Bool { NavigationPolicy.trusted(url) }
    @objc private func reconnect() { retry.isHidden = true; web.load(URLRequest(url: home)) }
    @objc private func resume() { web?.evaluateJavaScript("window.dispatchEvent(new Event('focus'))", completionHandler: nil) }
    private func failure() { loading.stopAnimating(); retry.isHidden = false }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading.startAnimating() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading.stopAnimating(); retry.isHidden = true }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { failure() } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { failure() } }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure() }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if trusted(url) { decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow); return }
        if navigationAction.targetFrame?.isMainFrame == false { decisionHandler(.cancel); return }
        if navigationAction.navigationType == .linkActivated && ["https", "http", "mailto", "tel"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard trusted(navigationResponse.response.url) else { decisionHandler(.cancel); return }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if trusted(navigationAction.request.url) { webView.load(navigationAction.request) }
        else if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
        return nil
    }

    private func destination(_ name: String) throws -> URL {
        let safe = String((name as NSString).lastPathComponent.prefix(120)).replacingOccurrences(of: ":", with: "-")
        guard !safe.isEmpty, ["json", "html"].contains((safe as NSString).pathExtension.lowercased()) else { throw NSError(domain: "XiWang", code: 1) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(safe)
    }
    private func showShare(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        controller.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        present(controller, animated: true)
    }
    private func downloadError() {
        let alert = UIAlertController(title: "导出未完成", message: "请重新导出。若文件超过 10 MB，可在 Safari 中打开膝望并导出。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        if presentedViewController == nil { present(alert, animated: true) }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "xiwangDownload", message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https", message.frameInfo.securityOrigin.host == home.host,
              let body = message.body as? [String: String] else { return }
        if body["error"] != nil { downloadError(); return }
        guard let name = body["name"], let encoded = body["base64"], encoded.utf8.count <= 14_000_000 else { downloadError(); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                guard let bytes = Data(base64Encoded: encoded), bytes.count <= 10_000_000 else { throw NSError(domain: "XiWang", code: 2) }
                let url = try self.destination(name)
                try bytes.write(to: url, options: .atomic)
                DispatchQueue.main.async { self.showShare(url) }
            } catch { DispatchQueue.main.async { self.downloadError() } }
        }
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard trusted(response.url), response.expectedContentLength <= 10_000_000 else { completionHandler(nil); downloadError(); return }
        do { let url = try destination(suggestedFilename); downloads[ObjectIdentifier(download)] = url; completionHandler(url) }
        catch { completionHandler(nil); downloadError() }
    }
    func downloadDidFinish(_ download: WKDownload) { if let url = downloads.removeValue(forKey: ObjectIdentifier(download)) { showShare(url) } }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let url = downloads.removeValue(forKey: ObjectIdentifier(download)) { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        downloadError()
    }
}

private final class WeakDownloadHandler: NSObject, WKScriptMessageHandler {
    weak var owner: BrowserController?
    init(_ owner:BrowserController) { self.owner = owner }
    func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage) { owner?.userContentController(controller,didReceive:message) }
}
