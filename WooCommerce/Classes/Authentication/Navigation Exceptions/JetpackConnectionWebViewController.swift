import UIKit
import WebKit

final class JetpackConnectionWebViewController: UIViewController {

    private let siteURL: String
    private lazy var webView: WKWebView = {
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        return webView
    }()

    init(siteURL: String) {
        self.siteURL = siteURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureWebView()
    }
}

private extension JetpackConnectionWebViewController {
    func configureWebView() {
        view.addSubview(webView)
        view.pinSubviewToSafeArea(webView)

        guard let escapedSiteURL = siteURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: String(format: Constants.jetpackInstallString, escapedSiteURL, Constants.mobileRedirectURL)) else {
            return
        }

        let request = URLRequest(url: url)
        webView.load(request)
    }

    func handleMobileRedirect() {
        // TODO-7269
    }
}

extension JetpackConnectionWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationURL = navigationAction.request.url?.absoluteString
        switch navigationURL {
        case let .some(url) where url == Constants.mobileRedirectURL:
            decisionHandler(.cancel)
            handleMobileRedirect()
        default:
            decisionHandler(.allow)
        }
    }
}

private extension JetpackConnectionWebViewController {
    enum Constants {
        static let jetpackInstallString = "https://wordpress.com/jetpack/connect?url=%@&mobie-redirect=%@from=mobile"
        static let mobileRedirectURL = "woocommerce://jetpack-connected"
    }
}
