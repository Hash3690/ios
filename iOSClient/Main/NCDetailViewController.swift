//
//  NCDetailViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import WebKit
import NCCommunication
//import ATGMediaBrowser

class NCDetailViewController: UIViewController, MediaBrowserViewControllerDelegate, MediaBrowserViewControllerDataSource {
    
    @IBOutlet weak var backgroundView: UIImageView!
    
    @objc var metadata: tableMetadata?
    @objc var selector: String?

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var mediaBrowser: MediaBrowserViewController?
    private var metadatas = [tableMetadata]()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        appDelegate.activeDetail = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeDisplayMode), name: NSNotification.Name(rawValue: "changeDisplayMode"), object: nil)

        changeTheming()
        
        if metadata != nil  {
            viewFile(metadata: metadata!, selector: selector)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if appDelegate.player != nil && appDelegate.player.rate != 0 {
            appDelegate.player.pause()
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerMedia.sharedInstance.removeObserver()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
        }
    }
    
    func viewUnload() {
        if let splitViewController = self.splitViewController as? NCSplitViewController {
            if splitViewController.isCollapsed {
                if let navigationController = splitViewController.viewControllers.last as? UINavigationController {
                    navigationController.popToRootViewController(animated: true)
                }
            } else {
                for view in backgroundView.subviews {
                    view.removeFromSuperview()
                }
                self.navigationController?.navigationBar.topItem?.title = ""
            }
        }
    }
    
    @objc func changeTheming() {
        backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brand.withAlphaComponent(0.4))
        view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
   
    @objc func changeDisplayMode() {
        mediaBrowser?.changeInViewSize(to: backgroundView.frame.size)
    }
    
    func subViewActive() -> UIView? {
        return backgroundView.subviews.first
    }
    
    @objc func viewFile(metadata: tableMetadata, selector: String?) {
                
        self.metadata = metadata
        self.selector = selector
        
        self.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) == false {
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, extension: (metadata.fileNameView as NSString).pathExtension, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerMedia.sharedInstance.removeObserver()
        }
        
        // IMAGE
        if metadata.typeFile == k_metadataTypeFile_image {
            
            if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND typeFile == %@", metadata.account, metadata.serverUrl, k_metadataTypeFile_image), sorted: CCUtility.getOrderSettings(), ascending: CCUtility.getAscendingSettings()) {
                if metadatas.count > 0 {
                    // build data source
                    self.metadatas.removeAll()
                    var index = 0
                    for metadata in metadatas {
                        if metadata.ocId == self.metadata!.ocId {
                            index = 0
                        }
                        self.metadatas.insert(metadata, at: index)
                        index += 1
                    }
                    
                    mediaBrowser = MediaBrowserViewController(dataSource: self)
                    if mediaBrowser != nil {
                        mediaBrowser!.shouldShowPageControl = false
                        mediaBrowser!.enableInteractiveDismissal = false
                        mediaBrowser!.view.frame = CGRect(x: 0, y: 0, width: backgroundView.frame.width, height: backgroundView.frame.height)

                        addChild(mediaBrowser!)
                        backgroundView.addSubview(mediaBrowser!.view)
                        mediaBrowser!.didMove(toParent: self)
                        
                        mediaBrowser!.changeInViewSize(to: backgroundView.frame.size)
                    }
                }
            }
            return
        }
        
        // AUDIO VIDEO
        if metadata.typeFile == k_metadataTypeFile_audio || metadata.typeFile == k_metadataTypeFile_video {
            NCViewerMedia.sharedInstance.viewMedia(metadata, view: backgroundView)
            return
        }
        
        // DOCUMENT - INTERNAL VIEWER
        if metadata.typeFile == k_metadataTypeFile_document && selector != nil && selector == selectorLoadFileInternalView {
            NCViewerDocumentWeb.sharedInstance.viewDocumentWebAt(metadata, view: backgroundView)
            return
        }
        
        // DOCUMENT
        if metadata.typeFile == k_metadataTypeFile_document {
            
            // PDF
            if metadata.contentType == "application/pdf" {
                if #available(iOS 11.0, *) {
                    let viewerPDF = NCViewerPDF.init(frame: backgroundView.frame)
                    
                    let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) == false {
                        return
                    }
                    
                    viewerPDF.setupPdfView(filePath: URL(fileURLWithPath: filePath), view: backgroundView)
                }
                
                return
            }
            
            // DirectEditinf: Nextcloud Text - OnlyOffice
            if NCUtility.sharedInstance.isDirectEditing(metadata) != nil && appDelegate.reachability.isReachable() {
                
                let editor = NCUtility.sharedInstance.isDirectEditing(metadata)!
                if editor == k_editor_text || editor == k_editor_onlyoffice {
                    
                    NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)

                    if metadata.url == "" {
                        
                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
                        
                        if editor == k_editor_onlyoffice {
                            customUserAgent = NCUtility.sharedInstance.getCustomUserAgentOnlyOffice()
                        }
                        
                        NCCommunication.sharedInstance.NCTextOpenFile(urlString: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent, account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
                            
                            if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                                
                                let nextcloudText = NCViewerNextcloudText.init(frame: self.backgroundView.frame, configuration: WKWebViewConfiguration())
                                nextcloudText.viewerAt(url!, metadata: metadata, editor: editor, view: self.backgroundView, viewController: self)
                                if editor == k_editor_text && self.splitViewController!.isCollapsed {
                                    self.navigationController?.navigationItem.hidesBackButton = true
                                }
                                
                            } else if errorCode != 0 {
                                
                                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                self.navigationController?.popViewController(animated: true)
                                
                            } else {
                                
                                self.navigationController?.popViewController(animated: true)
                            }
                        }
                        
                    } else {
                        
                        let nextcloudText = NCViewerNextcloudText.init(frame: backgroundView.frame, configuration: WKWebViewConfiguration())
                        nextcloudText.viewerAt(metadata.url, metadata: metadata, editor: editor, view: backgroundView, viewController: self)
                        if editor == k_editor_text && self.splitViewController!.isCollapsed {
                            self.navigationController?.navigationItem.hidesBackButton = true
                        }
                    }
                }
                
                return
            }
            
            // RichDocument: Collabora
            if NCUtility.sharedInstance.isRichDocument(metadata) && appDelegate.reachability.isReachable() {
                
                NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)
                
                if metadata.url == "" {
                    
                    OCNetworking.sharedManager()?.createLinkRichdocuments(withAccount: appDelegate.activeAccount, fileId: metadata.fileId, completion: { (account, url, errorMessage, errorCode) in
                        
                        if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                            
                            let richDocument = NCViewerRichdocument.init(frame: self.backgroundView.frame, configuration: WKWebViewConfiguration())
                            richDocument.viewRichDocumentAt(url!, metadata: metadata, view: self.backgroundView, viewController: self)
                            if self.splitViewController != nil && self.splitViewController!.isCollapsed {
                                self.navigationController?.navigationItem.hidesBackButton = true
                            }
                            
                        } else if errorCode != 0 {
                            
                            NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            self.navigationController?.popViewController(animated: true)
                            
                        } else {
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                        
                    })
                    
                } else {
                    
                    let richDocument = NCViewerRichdocument.init(frame: backgroundView.frame, configuration: WKWebViewConfiguration())
                    richDocument.viewRichDocumentAt(metadata.url, metadata: metadata, view: backgroundView, viewController: self)
                    if self.splitViewController != nil && self.splitViewController!.isCollapsed {
                        self.navigationController?.navigationItem.hidesBackButton = true
                    }
                }
            }
        }
        
        // OTHER
        NCViewerDocumentWeb.sharedInstance.viewDocumentWebAt(metadata, view: backgroundView)
    }
    
    func numberOfItems(in mediaBrowser: MediaBrowserViewController) -> Int {
        
        return metadatas.count
    }

    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, imageAt index: Int, completion: @escaping MediaBrowserViewControllerDataSource.CompletionBlock) {

        let metadata = metadatas[index]
        if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 {
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if let image = UIImage.init(contentsOfFile: imagePath) {
                completion(index, image, ZoomScale.default, nil)
                return
            }
        } else if CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            let imagePath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            if let image = UIImage.init(contentsOfFile: imagePath) {
                completion(index, image, ZoomScale.default, nil)
                return
            }
        }
        
        completion(index, UIImage.init(named: "logo"), ZoomScale.default, nil)
    }
}
