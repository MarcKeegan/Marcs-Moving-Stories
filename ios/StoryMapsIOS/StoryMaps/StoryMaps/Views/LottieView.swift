import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let contentMode: UIView.ContentMode
    
    init(
        name: String,
        loopMode: LottieLoopMode = .loop,
        animationSpeed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.name = name
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: LottieView
        var animationView: LottieAnimationView?

        init(_ parent: LottieView) {
            self.parent = parent
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        context.coordinator.animationView = animationView
        
        animationView.contentMode = contentMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Load animation
        DotLottieFile.named(name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let file):
                    animationView.loadAnimation(from: file)
                    setupAndPlay(animationView)
                case .failure:
                    if let animation = LottieAnimation.named(name) {
                        animationView.animation = animation
                        setupAndPlay(animationView)
                    }
                }
            }
        }
        
        return view
    }
    
    private func setupAndPlay(_ animationView: LottieAnimationView) {
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.setNeedsLayout()
        animationView.layoutIfNeeded()
        animationView.play()
        print("▶️ Lottie play() called for: \(name)")
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let animationView = context.coordinator.animationView,
           animationView.animation != nil,
           !animationView.isAnimationPlaying {
            animationView.play()
        }
    }
}

