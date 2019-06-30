//
//  IntroTableViewController.swift
//  InteractiveModalDismissScrollView
//
//  Created by Andrew Ferrarone on 10/18/17.
//  Copyright © 2017 Andrew Ferrarone. All rights reserved.
//

import UIKit

class IntroTableViewController: UITableViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.title = "Interactive Dismiss"
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        self.handlePresentation()
    }

    private func handlePresentation()
    {
        let modalPresenter = ModalPresenter()
        modalPresenter.presentModalController(withPresenter: self)
    }
}

