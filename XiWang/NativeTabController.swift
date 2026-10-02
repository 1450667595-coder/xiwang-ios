import UIKit

final class NativeTabController: UITabBarController {
    private let browser = BrowserController()
    private let labels = ["今天", "记录", "计划"]
    override func viewDidLoad() {
        super.viewDidLoad()
        mode = .tabBar
        let symbols = ["waveform.path.ecg", "calendar", "slider.horizontal.3"]
        tabs = labels.enumerated().map { index, label in
            UITab(title: label, image: UIImage(systemName: symbols[index]), identifier: "kneehope-\(index)") { [browser] _ in
                BrowserTabPage(browser: browser, label: label)
            }
        }
        browser.onNavigationState = { [weak self] index, visible in
            guard let self else { return }
            if self.selectedIndex != index { self.selectedIndex = index }
            if self.isTabBarHidden == visible { self.setTabBarHidden(!visible, animated: true) }
        }
    }
}

private final class BrowserTabPage: UIViewController {
    private let browser: BrowserController
    private let label: String
    init(browser: BrowserController, label: String) { self.browser = browser; self.label = label; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use programmatic initialization") }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if browser.parent !== self {
            browser.willMove(toParent: nil)
            browser.view.removeFromSuperview()
            browser.removeFromParent()
            addChild(browser)
            browser.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(browser.view)
            NSLayoutConstraint.activate([
                browser.view.topAnchor.constraint(equalTo: view.topAnchor),
                browser.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                browser.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                browser.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            browser.didMove(toParent: self)
        }
        browser.selectNativeTab(label)
    }
}
