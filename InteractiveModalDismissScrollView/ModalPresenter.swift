//
//  ModalPresenter.swift
//  InteractiveModalDismissScrollView
//
//  Created by Andrew Ferrarone on 10/20/17.
//  Copyright © 2017 Andrew Ferrarone. All rights reserved.
//

import UIKit

enum PresentationState
{
    case presenting
    case dismissing
}

private let ANIMATION_DURATION_DEFAULT: TimeInterval = 0.4
private let ANIMATION_DURATION_LONG: TimeInterval = 0.5

// This view controller will be presented on top w/ a blurView, and it will present ModalController,
// We can't add a blurView onto the presentingController b/c it might be in a navigationController,
// and the navigationBar wouldn't be coverd by the blur view:
class ModalPresenter: UIViewController
{
    private var blurView = UIVisualEffectView(effect: nil)
    private var blurAnimator: UIViewPropertyAnimator?
    private var state: PresentationState = .presenting
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.view.addSubview(self.blurView)
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.blurView.frame = self.view.frame
    }
    
// MARK: - Public
    
    func presentModalController(withPresenter presenter: UIViewController)
    {
        let tableViewController = ModalController(style: .grouped)
        tableViewController.dragToDismissDelegate = self
        
        let navCon = UINavigationController(rootViewController: tableViewController)
        navCon.navigationBar.isTranslucent = false
        navCon.modalTransitionStyle = .coverVertical
        navCon.modalPresentationStyle = .custom // necessary for interactive transition
        
        // present us first (clear and un-animated):
        self.modalPresentationStyle = .overCurrentContext
        self.definesPresentationContext = true
        
        presenter.present(self, animated: false) {
            self.startTransition(state: self.state, duration: ANIMATION_DURATION_DEFAULT)
            self.present(navCon, animated: true, completion: nil)
        }
    }
    
// MARK: - Utilities
    
    private func startTransition(state: PresentationState, duration: TimeInterval, isInteractive: Bool = false)
    {
        self.addBlurAnimator(state: state, duration: duration)
        self.blurAnimator?.startAnimation()
        
        // pause animations immediately so we can scrub them interactively,
        // otherwise if not interactive, let them continue to run:
        if isInteractive {
            self.blurAnimator?.pauseAnimation()
        }
    }
    
    private func addBlurAnimator(state: PresentationState, duration: TimeInterval)
    {
        // lets make a timing curve that is slow then fast on the way in and fast then slow on the way out:
        var timing: UITimingCurveProvider
        
        switch state
        {
            case .presenting:
                timing = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.75, y: 0.1),
                                                 controlPoint2: CGPoint(x: 0.9, y: 0.25))
            case .dismissing:
                timing = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.1, y: 0.75),
                                                 controlPoint2: CGPoint(x: 0.25, y: 0.9))
        }
        
        self.blurAnimator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
        
        if #available(iOS 11.0, *) {
            self.blurAnimator?.scrubsLinearly = false
        }
        
        self.blurAnimator?.addAnimations {
            switch state {
                case .presenting: self.blurView.effect = UIBlurEffect(style: .light)
                case .dismissing: self.blurView.effect = nil
            }
        }
        
        self.blurAnimator?.addCompletion { _ in
            self.blurAnimator = nil
        }
    }
}

// MARK: - DragToDismissScrollInteractorDelegate
extension ModalPresenter: DragToDismissScrollInteractorDelegate
{
    func interactorDidStartInteractiveDismiss(_ interactor: DragToDismissScrollInteractor)
    {
        self.startTransition(state: .dismissing, duration: ANIMATION_DURATION_LONG, isInteractive: true)
    }
    
    func interactor(_ interactor: DragToDismissScrollInteractor, didUpdateInteraction progress: CGFloat)
    {
        self.blurAnimator?.fractionComplete = progress
    }
    
    func interactorDidFinishInteraction(_ interactor: DragToDismissScrollInteractor)
    {
        // finish animations:
        let timing = UICubicTimingParameters(animationCurve: .easeOut)
        self.blurAnimator?.continueAnimation(withTimingParameters: timing, durationFactor: 0)
    }
    
    func interactorDidCancelInteraction(_ interactor: DragToDismissScrollInteractor)
    {
        // toggle reverse and continue:
        self.state = .presenting
        
        self.blurAnimator?.isReversed = !(self.blurAnimator?.isReversed ?? false)
        self.blurAnimator?.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        
        self.blurAnimator?.addCompletion { _ in
            self.blurView.effect = self.state == .presenting ? UIBlurEffect(style: .light) : nil
        }
    }
    
    func interactorDidFinishDismiss(_ interactor: DragToDismissScrollInteractor)
    {
        // safe to dismiss us away:
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    func interactorWillDismissNonInteractively(_ interactor: DragToDismissScrollInteractor)
    {
        self.startTransition(state: .dismissing, duration: ANIMATION_DURATION_DEFAULT, isInteractive: false)
    }
}
