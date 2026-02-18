import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
                
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .red   // obvious test color

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let root = storyboard.instantiateInitialViewController() else {
            fatalError("Initial VC not found in Main.storyboard")
        }

        window.rootViewController = root
        window.makeKeyAndVisible()

        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
