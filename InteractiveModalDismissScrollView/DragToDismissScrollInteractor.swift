//
//  DragToDismissScrollInteractor.swift
//  InteractiveModalDismissScrollView
//
//  Created by Andrew Ferrarone on 10/18/17.
//  Copyright © 2017 Andrew Ferrarone. All rights reserved.
//

import UIKit

private let ANIMATION_DURATION_DISMISS: TimeInterval = 0.5
private let THRESHOLD_FINISH: CGFloat = 0.25
private let GRAVITY_DIRECTION = CGVector(dx: 0, dy: 4.0) //a little faster
private let SNAP_DAMPING: CGFloat = 0.3
private let VELOCITY_VERTICAL_SLOW: CGFloat = 1000.0

protocol DragToDismissScrollInteractorDelegate: class
{
    func interactorDidStartInteractiveDismiss(_ interactor: DragToDismissScrollInteractor)
    func interactor(_ interactor: DragToDismissScrollInteractor, didUpdateInteraction progress: CGFloat)
    func interactorDidFinishInteraction(_ interactor: DragToDismissScrollInteractor)
    func interactorDidCancelInteraction(_ interactor: DragToDismissScrollInteractor)
    func interactorDidFinishDismiss(_ interactor: DragToDismissScrollInteractor)
    func interactorWillDismissNonInteractively(_ interactor: DragToDismissScrollInteractor)
}

class DragToDismissScrollInteractor: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning
{
    fileprivate var context: UIViewControllerContextTransitioning?
    fileprivate var fromView: UIView?
    fileprivate var touchOffsetFromCenter: UIOffset?
    fileprivate var isDismissing = false
    
    private(set) var hasStartedInteraction = false
    weak var delegate: DragToDismissScrollInteractorDelegate?
    
    // required to use this class:
    fileprivate weak var sourceController: UIViewController!
    fileprivate weak var scrollView: UIScrollView!
    
    init(sourceController: UIViewController, scrollView: UIScrollView)
    {
        self.sourceController = sourceController
        self.scrollView = scrollView
        super.init()
        
        // lets use scrollView panGR to drive the interactive dismiss transition:
        self.scrollView.panGestureRecognizer.addTarget(self, action: #selector(DragToDismissScrollInteractor.handlePan(_:)))
    }
    
    deinit {
        print("DragToDismiss is leaving the heap")
    }
    
// MARK: - Public
    
    func handleNonInteractiveDismiss()
    {
        if !self.sourceController.isBeingDismissed {
            
            self.delegate?.interactorWillDismissNonInteractively(self)
            
            self.sourceController.presentingViewController?.dismiss(animated: true) {
                self.delegate?.interactorDidFinishDismiss(self)
            }
        }
    }
    
// MARK: - UIPanGestureRecognizer
    
    @objc private func handlePan(_ panGR: UIPanGestureRecognizer)
    {
        switch panGR.state
        {
            case .changed:
                self.handlePanChange(with: panGR)
            
            case .ended:
                self.handlePanEnd(with: panGR)
            
            default:
                if self.isDismissing {
                    self.cancelTransition()
                }
        }
    }
    
    private func handlePanChange(with panGR: UIPanGestureRecognizer)
    {
        if self.isDismissing {
            
            guard let fromView = self.fromView,
                let context = self.context,
                let touchOffsetFromCenter = self.touchOffsetFromCenter
                else { return }
            
            defer {
                // tell context and delegate to update the transition:
                self.delegate?.interactor(self, didUpdateInteraction: self.progressBasedOnFromViewLocation)
                self.context?.updateInteractiveTransition(self.progressBasedOnFromViewLocation)
            }
            
            // We are dismissing so update fromView center w/ pan offset:
            let touchLocation = self.scrollView.panGestureRecognizer.location(in: context.containerView)
            var newCenter = fromView.center
            
            // prevent user from dragging the frame higher than where it started (we just want to support dragging down to dismiss):
            newCenter.y = max(touchLocation.y - touchOffsetFromCenter.vertical, context.containerView.center.y)
            self.fromView?.center = newCenter
            
            // adjust the scrollView so that we aren't scrolling (bouncing) while dismissing:
            self.scrollView.contentOffset.y = 0
        }
        else {
            
            // only begin dismiss if we are at the top of the scrollView:
            guard self.isOverScrolling, self.progressBasedOnOverScroll > 0 else {
                
                if self.isDismissing {
                    self.cancelTransition()
                    self.isDismissing = false
                }
                
                return
            }
            
            // kick off the interactive dismiss:
            if !self.sourceController.isBeingDismissed {
                self.hasStartedInteraction = true
                self.delegate?.interactorDidStartInteractiveDismiss(self)
                self.sourceController.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func handlePanEnd(with panGR: UIPanGestureRecognizer)
    {
        guard self.isDismissing else { return }
        
        // if user has pulled down far enough finish, otherwise cancel:
        if self.progressBasedOnFromViewLocation >= THRESHOLD_FINISH {
            self.finishTransition(withVelocity: panGR.velocity(in: self.context?.containerView))
        }
        else {
            self.cancelTransition()
        }
    }
    
    private var isOverScrolling: Bool {
        return self.scrollView.contentOffset.y < self.scrollView.adjustedContentInset.top
    }
    
    private var progressBasedOnOverScroll: CGFloat {
        let overOffset = -(self.scrollView.adjustedContentInset.top + self.scrollView.contentOffset.y)
        let rawThresholdPercentage = overOffset / (self.sourceController.view.bounds.height)
        let progress = max(rawThresholdPercentage, 0)
        return progress
    }
    
    private var progressBasedOnFromViewLocation: CGFloat {
        guard let context = self.context,
            let fromController = context.viewController(forKey: .from),
            let fromView = self.fromView
            else { return 0 }
        
        let initialCenterY = context.initialFrame(for: fromController).midY
        let currentCenterY = fromView.center.y
        let offsetPercentage = (currentCenterY - initialCenterY) / context.initialFrame(for: fromController).height
        return max(offsetPercentage, 0)
    }
    
// MARK: - UIViewControllerAnimatedTransitioning
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return ANIMATION_DURATION_DISMISS
    }
    
    // This probably won't get called b/c we will return nil to the transition delegate if the transition
    // is not interactive and let the default system transition take effect...
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        guard let fromController = transitionContext.viewController(forKey: .from),
            let toController = transitionContext.viewController(forKey: .to)
            else { return }

        toController.view.frame = transitionContext.finalFrame(for: toController)
        fromController.view.frame = transitionContext.initialFrame(for: fromController)

        // animate us sliding down offscreen:
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), animations: {
            fromController.view.center.y = transitionContext.containerView.center.y + transitionContext.containerView.frame.height
            
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    
// MARK: - UIViewControllerInteractiveTransitioning
    
    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning)
    {
        guard let fromController = transitionContext.viewController(forKey: .from),
            let toController = transitionContext.viewController(forKey: .to)
            else { return }
        
        toController.view.frame = transitionContext.finalFrame(for: toController)
        fromController.view.frame = transitionContext.initialFrame(for: fromController)
                
        self.context = transitionContext
        self.fromView = fromController.view
        self.isDismissing = true
        
        // hold onto our current pan position/ center offset so we can pick up from here as user pans,
        // we will change fromViews center as user pans:
        let touchLocation = self.scrollView.panGestureRecognizer.location(in: self.fromView)
        let viewCenter = self.fromView!.center
        self.touchOffsetFromCenter = UIOffsetMake(touchLocation.x - viewCenter.x, touchLocation.y - viewCenter.y)
    }
    
// MARK: - Utilities
    
    private func finishTransition(withVelocity velocity: CGPoint)
    {
        defer {
            // let context and delegate know we are finished w/ interactive part of transition:
            self.context?.finishInteractiveTransition()
            self.delegate?.interactorDidFinishInteraction(self)
        }
        
        // If user is moving fast let's pick up the animation w/ their velocity,
        // otherwise user is going slow so let them drop the view off the screen w/ gravity:
        if velocity.y > VELOCITY_VERTICAL_SLOW {
            self.finish(withCurrentVelocity: velocity)
        }
        else {
            self.finishWithGravity()
        }
    }
    
    private func finish(withCurrentVelocity velocity: CGPoint)
    {
        guard let container = self.context?.containerView, let fromView = self.fromView else { return }
        
        // we need to normalize the velocity for the spring animation,
        // calculate distance left in animation then divide velocity by this value:
        let finalCenterY = container.center.y + container.frame.height
        let finalCenterYDelta = abs(fromView.center.y - finalCenterY)
        let initialSpringVelocity = velocity.y / finalCenterYDelta
        
        // animate using the current velocity:
        let timing = UISpringTimingParameters(dampingRatio: 0.7, initialVelocity: CGVector(dx: 0, dy: initialSpringVelocity))
        let animator = UIViewPropertyAnimator(duration: ANIMATION_DURATION_DISMISS, timingParameters: timing)
        
        animator.addAnimations {
            fromView.center.y = finalCenterY
        }
        
        animator.addCompletion { _ in
            self.completeTransition()
        }
        
        animator.startAnimation()
    }
    
    private func finishWithGravity()
    {
        guard let container = self.context?.containerView, let fromView = self.fromView else { return }
        
        // let gravity finish (drop us off the screen):
        let animator = UIDynamicAnimator(referenceView: container)
        
        let gravity = UIGravityBehavior(items: [fromView])
        gravity.gravityDirection = GRAVITY_DIRECTION
        
        gravity.action = { [weak self] in
            
            guard let strongSelf = self else { return }
            
            // once we have fallen offscreen we can finish and cleanup:
            if strongSelf.progressBasedOnFromViewLocation >= CGFloat(1.0) {
                animator.removeAllBehaviors()
                strongSelf.completeTransition()
            }
        }
        
        animator.addBehavior(gravity)
    }
    
    private func cancelTransition()
    {
        guard let container = self.context?.containerView,
            let fromController = self.context?.viewController(forKey: .from),
            let initialFrame = self.context?.initialFrame(for: fromController),
            let fromView = self.fromView
            else { return }
        
        defer {
            // let transition context and delegate know we are cancelling interaction and snap back:
            self.context?.cancelInteractiveTransition()
            self.delegate?.interactorDidCancelInteraction(self)
        }
        
        // snap back like a spring:
        let animator = UIDynamicAnimator(referenceView: container)
        let snapPoint = CGPoint(x: initialFrame.midX, y: initialFrame.midY)
        
        let itemBehavior = UIDynamicItemBehavior(items: [fromView])
        itemBehavior.allowsRotation = false
        animator.addBehavior(itemBehavior)
        
        let snap = UISnapBehavior(item: fromView, snapTo: snapPoint)
        snap.damping = SNAP_DAMPING
        
        snap.action = { [weak self] in
            
            guard let strongSelf = self, let fromView = strongSelf.fromView else { return }
            
            // when we have slowed to a stop at our initial position, we can complete and cleanup:
            if abs(fromView.frame.origin.y) < 1 && itemBehavior.linearVelocity(for: fromView).y < 0.01 {
                fromView.frame = initialFrame
                animator.removeAllBehaviors()
                strongSelf.completeTransition()
            }
        }
    
        animator.addBehavior(snap)
    }
    
    private func completeTransition()
    {
        let isFinished = !(self.context?.transitionWasCancelled ?? true)
        self.context?.completeTransition(isFinished)
        
        if isFinished {
            self.delegate?.interactorDidFinishDismiss(self)
        }
        
        // reset vars:
        self.context = nil
        self.touchOffsetFromCenter = .zero
        self.fromView = nil
        self.isDismissing = false
        self.hasStartedInteraction = false
    }
}
