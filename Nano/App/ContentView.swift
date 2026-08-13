import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var isSelectingInGallery = false
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        PagerView(
            pages: [
                AnyView(GalleryView(isSelecting: $isSelectingInGallery)),
                AnyView(CameraView()),
                AnyView(SettingsView())
            ],
            currentPage: $selectedTab,
            isScrollEnabled: !isSelectingInGallery
        )
        .background(Color.black)
        .ignoresSafeArea()
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                // Camera page: dim to 0%
                UIScreen.main.brightness = 0.0
            } else {
                // Gallery or Settings: 75% brightness
                UIScreen.main.brightness = 0.75
            }
        }
        .onAppear {
            // Start on camera = 0% brightness
            UIScreen.main.brightness = 0.0
        }
    }
}

// MARK: - UIPageViewController Wrapper with Scroll Toggle

struct PagerView: UIViewControllerRepresentable {
    var pages: [AnyView]
    @Binding var currentPage: Int
    var isScrollEnabled: Bool

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        if let firstVC = context.coordinator.controllers.first {
            pvc.setViewControllers([firstVC], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        // Enable or disable page scrolling dynamically
        for view in uiViewController.view.subviews {
            if let scrollView = view as? UIScrollView {
                scrollView.isScrollEnabled = isScrollEnabled
            }
        }

        if currentPage < context.coordinator.controllers.count {
            let currentVC = context.coordinator.controllers[currentPage]
            if uiViewController.viewControllers?.first != currentVC {
                let direction: UIPageViewController.NavigationDirection = (currentPage > context.coordinator.previousPage) ? .forward : .reverse
                uiViewController.setViewControllers([currentVC], direction: direction, animated: true)
                context.coordinator.previousPage = currentPage
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PagerView
        var controllers: [UIViewController]
        var previousPage: Int

        init(_ parent: PagerView) {
            self.parent = parent
            self.previousPage = parent.currentPage
            self.controllers = parent.pages.map { UIHostingController(rootView: $0) }
            for controller in controllers {
                controller.view.backgroundColor = .black
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index > 0 else { return nil }
            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController), index < controllers.count - 1 else { return nil }
            return controllers[index + 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let currentVC = pageViewController.viewControllers?.first, let index = controllers.firstIndex(of: currentVC) {
                parent.currentPage = index
                previousPage = index
            }
        }
    }
}
