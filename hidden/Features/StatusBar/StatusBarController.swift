//
//  StatusBarController.swift
//  vanillaClone
//
//  Created by Thanh Nguyen on 1/30/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

class StatusBarController {
    
    //MARK: - Variables
    private var timer:Timer? = nil
    
    //MARK: - BarItems

    // Created and named in declaration order on purpose: a status item registers
    // with the menu bar under its autosave name, and on macOS 27 every new name
    // lands left of the previous one, so the bar reads separator, spacers, arrow.
    private let btnExpandCollapse = StatusBarController.makeItem("hiddenbar_expandcollapse", length: NSStatusItem.variableLength)
    private let spacers: [NSStatusItem] = StatusBarController.makeSpacers()  // macOS 27 only, empty elsewhere
    private let btnSeparate = StatusBarController.makeItem("hiddenbar_separate", length: 1)
    private var btnAlwaysHidden:NSStatusItem? = nil
    // macOS 27 only: spacer block for the always-hidden section, mirroring the
    // main separators so a single inflated unit can't span wide displays (#4).
    private var alwaysHiddenSpacers: [NSStatusItem] = []
    
    private var btnHiddenLength: CGFloat = 20
    private var btnHiddenCollapseLength: CGFloat = 2000
    
    private var btnAlwaysHiddenLength: CGFloat = Preferences.alwaysHiddenSectionEnabled ? 20 : 0
    private var btnAlwaysHiddenEnableExpandCollapseLength: CGFloat = Preferences.alwaysHiddenSectionEnabled ? 2000 : 0
    
    private let imgIconLine = NSImage(named:NSImage.Name("ic_line"))
    
    private var isCollapsed: Bool {
        // Compare with > rather than == so the state survives updateCollapsedLengths
        // changing btnHiddenCollapseLength while the bar is collapsed (PR #354).
        return self.btnSeparate.length > self.btnHiddenLength
    }
    
    private var isBtnSeparateValidPosition: Bool {
        guard
            let btnExpandCollapseX = self.btnExpandCollapse.button?.getOrigin?.x,
            let btnSeparateX = self.btnSeparate.button?.getOrigin?.x
            else {return false}
        
        if Constant.isUsingLTRLanguage {
            return btnExpandCollapseX >= btnSeparateX
        } else {
            return btnExpandCollapseX <= btnSeparateX
        }
    }
    
    private var isBtnAlwaysHiddenValidPosition: Bool {
        if !Preferences.alwaysHiddenSectionEnabled { return true }
        
        guard
            let btnSeparateX = self.btnSeparate.button?.getOrigin?.x,
            let btnAlwaysHiddenX = self.btnAlwaysHidden?.button?.getOrigin?.x
            else {return false}
        
        if Constant.isUsingLTRLanguage {
            return btnSeparateX >= btnAlwaysHiddenX
        } else {
            return btnSeparateX <= btnAlwaysHiddenX
        }
    }
    
    private var isToggle = false

    // macOS 27 keeps every item's position in its own layout table, keyed by
    // autosave name, and the app can neither read nor seed it. A new item always
    // lands leftmost. The spacers can therefore only end up between the arrow
    // and the separator if all three are registered fresh, in order, so on 27 the
    // items use new names. Upgraders drag their icons past the separator once,
    // as on a fresh install.
    private static let autosaveSuffix: String = {
        if #available(macOS 27.0, *) { return "_v27" }
        return ""
    }()

    // macOS 27 drops a status item whose length reaches half the display width
    // instead of clamping it (#360). Measured on 27.0: a 3008pt display keeps
    // 1480pt and drops 1500pt. One length is applied on every display's bar, so
    // the unit is sized under the NARROWEST display's cliff.
    @available(macOS 27.0, *)
    private static var collapseUnit: CGFloat {
        let narrowest = NSScreen.screens.map { $0.frame.width }.min() ?? 1728
        return max(200, (narrowest / 2 - 64).rounded(.down))
    }

    private static func makeItem(_ name: String, length: CGFloat) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = name + autosaveSuffix
        return item
    }

    // Below the cliff macOS 27 pushes the icons left of the separator into its
    // native overflow menu («), but only once they reach the frontmost app's
    // menus. One unit does not span that distance on wide displays, so the
    // separator gets company: zero-length items to its right that inflate with
    // it. macOS overflows from the left, so the icons go first and the spacers
    // stay; surplus spacers overflow themselves, which is harmless. The count
    // is fixed so every launch registers the same names: a name first seen on a
    // later launch would land leftmost, outside the block. Eleven units cover a
    // ~14900pt display next to an 1800pt one (10 spacers + separator).
    private static func makeSpacers() -> [NSStatusItem] {
        guard #available(macOS 27.0, *) else { return [] }
        return (0..<10).map { index in
            let item = makeItem("hiddenbar_spacer\(index)", length: 0)
            item.button?.isEnabled = false
            item.isVisible = false
            return item
        }
    }

    // Same idea as makeSpacers, but for the always-hidden section: a single
    // inflated item can't span a wide display on macOS 27 (half-width cliff),
    // so the always-hidden zone gets its own spacer block (#4).
    private static func makeAlwaysHiddenSpacers() -> [NSStatusItem] {
        guard #available(macOS 27.0, *) else { return [] }
        return (0..<10).map { index in
            let item = makeItem("hiddenbar_ahspacer\(index)", length: 0)
            item.button?.isEnabled = false
            item.isVisible = false
            return item
        }
    }

    // Spacers are visible only while collapsed. isVisible keeps the item's slot
    // in the layout table, so they come back between the arrow and the
    // separator and take no room in the expanded bar.
    private func setSpacersInflated(_ inflated: Bool) {
        for spacer in spacers {
            spacer.isVisible = inflated
            spacer.length = inflated ? btnHiddenCollapseLength : 0
        }
    }

    private var hoverMonitor: Any?
    private var hoverDwellTimer: Timer?

    // True while the pointer sits in any screen's menubar band (the strip between
    // visibleFrame.maxY and frame.maxY, which is the menubar's exact height there).
    // On fullscreen spaces the menubar is hidden and the band collapses to ~zero,
    // so this returns false there: intentional, no visible menubar = no deferral.
    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY && mouse.y <= screen.frame.maxY
        }
    }

    // The preferences window is an ordinary app window, not in the menu bar, so
    // the mouse-in-menubar guard does not cover it. With "use full menu bar on
    // expanding" on, an auto-collapse deactivates the app and dismisses this
    // window mid-edit (#170, same family as #66/#151). Defer the collapse while
    // it is on screen. isWindowLoaded short-circuits without force-loading the
    // window when preferences were never opened.
    private var isPreferencesWindowVisible: Bool {
        let wc = PreferencesWindowController.shared
        return wc.isWindowLoaded && (wc.window?.isVisible ?? false)
    }
    
    //MARK: - Methods
    init() {
        updateCollapsedLengths()
        setupUI()
        performLayoutMigrationIfNeeded()
        restoreRemovedStatusItems()
        setupAlwayHideStatusBar()
        setupHoverToExpandIfEnabled()
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.restoreCollapsedState()
        }
        
        if Preferences.areSeparatorsHidden {hideSeparators()}
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hoverDwellTimer?.invalidate()
        if let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // Opt-in via `defaults write com.dwarvesv.minimalbar hoverToExpand -bool true`.
    // No monitor is installed at all unless the pref is true at launch.
    private func setupHoverToExpandIfEnabled() {
        guard Preferences.hoverToExpand else { return }
        NSLog("HoverToExpand: enabled, installing global mouse monitor")
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            guard self.isCollapsed && self.isMouseInMenuBar else {
                self.hoverDwellTimer?.invalidate()
                self.hoverDwellTimer = nil
                return
            }
            // Short dwell so a pointer merely passing through doesn't expand.
            guard self.hoverDwellTimer == nil else { return }
            self.hoverDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.hoverDwellTimer = nil
                if self.isCollapsed && self.isMouseInMenuBar {
                    self.expandMenubar()
                }
            }
        }
    }
    
    @objc private func handleScreenParametersChanged() {
        // Re-apply the recomputed length to the LIVE item when collapsed, or a
        // display hot-plug leaves the separator at a stale length (PR #354).
        let wasCollapsed = isCollapsed
        updateCollapsedLengths()
        if wasCollapsed {
            btnSeparate.length = btnHiddenCollapseLength
            setSpacersInflated(true)
            if Preferences.areSeparatorsHidden {
                btnAlwaysHidden?.length = btnAlwaysHiddenEnableExpandCollapseLength
                setAlwaysHiddenSpacersInflated(true)
            }
        }
    }

    private func updateCollapsedLengths() {
        let boundedCollapseLength: CGFloat
        if #available(macOS 27.0, *) {
            // See collapseUnit and makeSpacers: one unit per item, spacers make
            // up the rest of the span. Displaced icons go into the native
            // overflow menu rather than off-screen.
            boundedCollapseLength = StatusBarController.collapseUnit
        } else {
            // The menubar replicates across every attached display, so the collapse
            // length must cover the WIDEST screen, not NSScreen.main (the focused one);
            // sizing from a narrower screen leaks hidden icons on wider displays.
            // frame.width, not visibleFrame: the menubar spans the full frame width.
            let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
            // Keep collapse length bounded to avoid pathological layout/memory behavior;
            // macOS enforces a hard 10,000pt maximum on NSStatusItem.length (PR #354).
            boundedCollapseLength = max(500, min(screenWidth * 2, 10_000))
        }
        btnHiddenCollapseLength = boundedCollapseLength
        btnAlwaysHiddenEnableExpandCollapseLength = Preferences.alwaysHiddenSectionEnabled ? boundedCollapseLength : 0
    }
    
    private func restoreRemovedStatusItems() {
        // Cmd-dragging a status item off the bar is persisted by macOS via
        // autosaveName, leaving the app running but unreachable. These items are
        // the app's only UI, so they self-restore at launch.
        btnExpandCollapse.isVisible = true
        btnSeparate.isVisible = true
    }

    // #5: On the first launch under the macOS 27 autosave names, drop any saved
    // bar positions so Hidden Bar's own items register in declaration order
    // (arrow, spacers, separator, always-hidden). This avoids a manual re-drag of
    // the app's own controls after upgrading from a pre-27 build. Note: other
    // apps' icons may still need a one-time drag — macOS won't let one app
    // reposition another's menu-bar items.
    private func performLayoutMigrationIfNeeded() {
        let key = "v27LayoutMigrated"
        guard #available(macOS 27.0, *),
              !UserDefaults.standard.bool(forKey: key) else { return }
        for item in [btnExpandCollapse] + spacers + [btnSeparate] {
            let name = item.autosaveName
            item.autosaveName = nil
            item.autosaveName = name
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private func setupUI() {
        if let button = btnSeparate.button {
            button.image = self.imgIconLine
        }
        let menu = self.getContextMenu()
        btnSeparate.menu = menu

        updateAutoCollapseMenuTitle()
        
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
            button.target = self
            
            button.action = #selector(self.btnExpandCollapsePressed(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc func btnExpandCollapsePressed(sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {

            let isOptionKeyPressed = event.modifierFlags.contains(NSEvent.ModifierFlags.option)

            if event.type == NSEvent.EventType.leftMouseUp && !isOptionKeyPressed{
                self.expandCollapseIfNeeded()
            } else if event.type == NSEvent.EventType.rightMouseUp && !isOptionKeyPressed {
                // Right-click opens the same context menu the separator has (#356),
                // making settings reachable from the control everyone clicks.
                // The separators/always-hidden toggle stays on option-click.
                showContextMenu(from: sender)
            } else {
                // Both option+left and option+right land here: separators toggle.
                self.showHideSeparatorsAndAlwayHideArea()
            }
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        guard let menu = btnSeparate.menu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 5), in: button)
    }
    
    func showHideSeparatorsAndAlwayHideArea() {
        Preferences.areSeparatorsHidden ? self.showSeparators() : self.hideSeparators()
        
        if self.isCollapsed {self.expandMenubar()}
    }
    
    private func showSeparators() {
        Preferences.areSeparatorsHidden = false
        
        if !self.isCollapsed {
            self.btnSeparate.length = self.btnHiddenLength
        }
        self.btnAlwaysHidden?.length = self.btnAlwaysHiddenLength
        self.setAlwaysHiddenSpacersInflated(false)
    }
    
    private func hideSeparators() {
        guard self.isBtnAlwaysHiddenValidPosition else {return}
        
        Preferences.areSeparatorsHidden = true
        
        if !self.isCollapsed {
            self.btnSeparate.length = self.btnHiddenLength
        }
        self.btnAlwaysHidden?.length = self.btnAlwaysHiddenEnableExpandCollapseLength
        self.setAlwaysHiddenSpacersInflated(true)
    }
    
    func expandCollapseIfNeeded() {
        //prevented rapid click cause icon show many in Dock
        if isToggle {return}
        isToggle = true
        self.isCollapsed ? self.expandMenubar() : self.collapseMenuBar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isToggle = false
        }
    }
    
    private func restoreCollapsedState(attemptsLeft: Int = 10) {
        if !isBtnSeparateValidPosition {
            if attemptsLeft > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.restoreCollapsedState(attemptsLeft: attemptsLeft - 1)
                }
                return
            }
            // Position still invalid after all retries — macOS layout not ready.
            // Default to EXPANDED (safe), don't force collapse which hides icons.
            expandMenubar(isInitialRestore: true)
            autoCollapseIfNeeded()
            return
        }
        
        // On launch, always start EXPANDED. Restore collapsed state only if
        // auto-hide is enabled (user expects auto-collapse behavior).
        // This prevents collapsing while other apps are still registering items.
        if Preferences.isAutoHide && Preferences.lastCollapsedState {
            collapseMenuBar()
        } else {
            expandMenubar(isInitialRestore: true)
        }
        autoCollapseIfNeeded()
    }

    private func collapseMenuBar() {
        guard self.isBtnSeparateValidPosition && !self.isCollapsed else {
            autoCollapseIfNeeded()
            return
        }

        btnSeparate.length = self.btnHiddenCollapseLength
        setSpacersInflated(true)
        setSeparatorGlyphVisible(false)
        if let button = btnExpandCollapse.button {
            button.image = Assets.expandImage
        }
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
        Preferences.lastCollapsedState = true
    }
    private func expandMenubar(isInitialRestore: Bool = false) {
        guard self.isCollapsed else {return}
        btnSeparate.length = btnHiddenLength
        setSpacersInflated(false)
        setSeparatorGlyphVisible(true)
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
        }
        if !isInitialRestore {
            autoCollapseIfNeeded()
        }
        
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
        }
        Preferences.lastCollapsedState = false
    }
    
    private func autoCollapseIfNeeded() {
        guard Preferences.isAutoHide else {return}
        guard !isCollapsed else { return }

        startTimerToAutoHide()
    }

    // The button draws the "|" glyph centered in the item's span. On macOS <= 26
    // that span is off-screen while collapsed; on 27 it is on-screen, showing a
    // stray line mid-menu-bar (#360). Clicks still land on the item.
    private func setSeparatorGlyphVisible(_ visible: Bool) {
        guard #available(macOS 27.0, *) else { return }
        btnSeparate.button?.image = visible ? imgIconLine : nil
    }

    private func startTimerToAutoHide() {
        timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: Preferences.numberOfSecondForAutoHide, repeats: false) { [weak self] _ in
            guard let self = self, Preferences.isAutoHide else { return }
            // Don't yank the bar shut mid-interaction: while the pointer is in the
            // menubar (hovering, clicking, dragging icons), defer and re-arm.
            // Intentionally unbounded; each re-arm invalidates the previous timer,
            // so deferral never accumulates timers.
            if self.isMouseInMenuBar || self.isPreferencesWindowVisible {
                self.startTimerToAutoHide()
            } else {
                self.collapseMenuBar()
            }
        }
    }
    
    private func getContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let prefItem = NSMenuItem(title: "Preferences...".localized, action: #selector(openPreferenceViewControllerIfNeeded), keyEquivalent: "P")
        prefItem.target = self
        menu.addItem(prefItem)
        
        let toggleAutoHideItem = NSMenuItem(title: "Toggle Auto Collapse".localized, action: #selector(toggleAutoHide), keyEquivalent: "t")
        toggleAutoHideItem.target = self
        toggleAutoHideItem.tag = 1
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoHide), name: .prefsChanged, object: nil)
        menu.addItem(toggleAutoHideItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    private func updateAutoCollapseMenuTitle() {
        guard let toggleAutoHideItem = btnSeparate.menu?.item(withTag: 1) else { return }
        if Preferences.isAutoHide {
            toggleAutoHideItem.title = "Disable Auto Collapse".localized
        } else {
            toggleAutoHideItem.title = "Enable Auto Collapse".localized
        }
    }
    
    @objc func updateAutoHide() {
        updateAutoCollapseMenuTitle()
        autoCollapseIfNeeded()
    }
    
    @objc func openPreferenceViewControllerIfNeeded() {
        Util.showPrefWindow()
    }
    
    @objc func toggleAutoHide() {
        Preferences.isAutoHide.toggle()
    }
}


//MARK: - Alway hide feature
extension StatusBarController {
    private func setupAlwayHideStatusBar() {
        NotificationCenter.default.addObserver(self, selector: #selector(toggleStatusBarIfNeeded), name: .alwayHideToggle, object: nil)
        toggleStatusBarIfNeeded()
    }
    @objc private func toggleStatusBarIfNeeded() {
        updateCollapsedLengths()

        if Preferences.alwaysHiddenSectionEnabled {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = NSStatusBar.system.statusItem(withLength: btnAlwaysHiddenLength)
            if let button = btnAlwaysHidden?.button {
                button.image = self.imgIconLine
                button.appearsDisabled = true
            }
            self.btnAlwaysHidden?.autosaveName = "hiddenbar_terminate" + StatusBarController.autosaveSuffix
            self.btnAlwaysHidden?.isVisible = true

            // macOS 27: give the always-hidden section its own spacer block so a
            // single inflated item can't span wide displays (#4).
            self.alwaysHiddenSpacers = StatusBarController.makeAlwaysHiddenSpacers()
            self.setAlwaysHiddenSpacersInflated(Preferences.areSeparatorsHidden)
        } else {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = nil
            for spacer in alwaysHiddenSpacers { NSStatusBar.system.removeStatusItem(spacer) }
            self.alwaysHiddenSpacers = []
        }
    }

    // Mirror setSpacersInflated for the always-hidden section's spacer block (#4).
    private func setAlwaysHiddenSpacersInflated(_ inflated: Bool) {
        guard btnAlwaysHidden != nil else { return }
        for spacer in alwaysHiddenSpacers {
            spacer.isVisible = inflated
            spacer.length = inflated ? btnAlwaysHiddenEnableExpandCollapseLength : 0
        }
    }
}
