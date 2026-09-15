//
//  AboutViewController.swift
//  Hidden Bar
//
//  Created by phucld on 12/19/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {

    @IBOutlet weak var lblVersion: NSTextField!
    
    static func initWithStoryboard() -> AboutViewController {
        let vc = NSStoryboard(name:"Main", bundle: nil).instantiateController(withIdentifier: "aboutVC") as! AboutViewController
        return vc
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        guard let version = Bundle.main.releaseVersionNumber,
                let buildNumber = Bundle.main.buildVersionNumber else { return }
        lblVersion.stringValue += " \(version) (\(buildNumber))"
        addMaintainerCredit()
    }

    // Fork maintainer credit with a clickable link to the maintainer's site.
    private func addMaintainerCredit() {
        let link = HyperlinkTextField()
        link.href = "https://dotoca.net"
        link.stringValue = "Maintained by Vitalii Tereshchuk (xVoLAnD)"
        link.isEditable = false
        link.isSelectable = false
        link.isBordered = false
        link.drawsBackground = false
        link.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        link.textColor = .secondaryLabelColor
        link.alignment = .center
        link.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(link)
        NSLayoutConstraint.activate([
            link.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            link.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32)
        ])
    }

}
