//
//  ModalController.swift
//  InteractiveModalDismissScrollView
//
//  Created by Andrew Ferrarone on 10/18/17.
//  Copyright © 2017 Andrew Ferrarone. All rights reserved.
//

import UIKit

private let ID_CELL = "cell"

final class ModalController: UITableViewController
{
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(#imageLiteral(resourceName: "CancelIcon").withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.tintColor = .darkGray
        button.addTarget(self, action: #selector(ModalController.handleCancel(_:)), for: .touchUpInside)
        return button
    }()
    
    private(set) var dragToDismiss: DragToDismissScrollInteractor?
    
    weak var dragToDismissDelegate: DragToDismissScrollInteractorDelegate?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.title = "Modal Controller"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.cancelButton)
        
        // tableView config:
        self.tableView.allowsSelection = false
        self.tableView.showsVerticalScrollIndicator = false 
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: ID_CELL)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if let navCon = self.navigationController, self.dragToDismiss == nil {
            self.dragToDismiss = DragToDismissScrollInteractor(sourceController: navCon, scrollView: self.tableView)
            self.dragToDismiss?.delegate = self.dragToDismissDelegate
            navCon.transitioningDelegate = self
            navCon.modalPresentationStyle = .custom
        }
    }
    
    deinit {
        print("ModalController is leaving the heap")
    }
    
// MARK: - Actions
    
    @objc private func handleCancel(_ sender: UIButton)
    {
        self.dragToDismiss?.handleNonInteractiveDismiss()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return 20
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: ID_CELL, for: indexPath)
        cell.textLabel?.text = "cell \((indexPath as NSIndexPath).row)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return "Section title"
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        return "Footer title"
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension ModalController: UIViewControllerTransitioningDelegate
{
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return self.dragToDismiss?.hasStartedInteraction ?? false ? self.dragToDismiss : nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning?
    {
        return self.dragToDismiss?.hasStartedInteraction ?? false ? self.dragToDismiss : nil
    }
}
