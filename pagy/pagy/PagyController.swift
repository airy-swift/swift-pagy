//
//  PagyController.swift
//  pagy
//
//  Created by Sota Iwahashi on 2021/10/16.
//

import UIKit



enum PagyStatus {
    case refreshing     // pull to refreshで表示しているデータを刷新する
    case pageLoading    // 画面下端まで行って次のpageを読み込む
    case available      // 何も読み込み中でなく、load可能
    case pageEnd        // 読み込めるpageが無くなったのでrefreshのみ可能
}


public class PagyController<T>: NSObject, UIScrollViewDelegate {
    override init() {
        super.init()
        // initialize spinner
        spinner.color = UIColor.darkGray
        spinner.hidesWhenStopped = true
        let pad: CGFloat = 30.0
        let origin: CGRect = spinner.frame
        let newFrame = CGRect(x: origin.minX, y: origin.minY, width: origin.width + pad * 2, height: origin.height + pad * 2)
        spinner.frame = newFrame
        
        // initalize refresh controll
        refreshCtl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
    }
    
    // lifetimeを管理する
    private var timer: Timer = Timer()
    
    // timerを設定する
    public var lifetime: Int = 0 {
        didSet {
            // timerの破棄
            timer.invalidate()
            
            timer = Timer.scheduledTimer(timeInterval: TimeInterval(lifetime), target: self, selector: #selector(updateLifetimeStatus), userInfo: nil, repeats: true)
        }
    }
    
    // pagingしたいlistのデータ
    private(set) public var listData: [T]? = nil
    
    // 初回のデータ取得は完了しているか？
    private(set) public var hasInitialLoad: Bool = false
    
    // tableのreloadするやつ
    public var reloadData: (() -> Void)? = nil
    
    // loading indicator
    public let refreshCtl = UIRefreshControl()
    public let spinner = UIActivityIndicatorView(style: .medium)
    
    
    // load callback
    public var pagingCallBack: ((@escaping ([T], Bool)->Void) -> Void)?;
    public var refreshCallback: ((@escaping ([T])->Void) -> Void)?
    
    // lifetime flag
    public var needLifetimeRefresh: Bool = false;
    
    // page counter
    private(set) public var page: Int = 1
    
    // manage loading status
    internal var loadStatus: PagyStatus = .available {
        didSet {
            print(self.loadStatus)
            switch loadStatus {
            case .pageLoading:
                page += 1
                spinner.startAnimating()
            case .available:
                spinner.stopAnimating()
                refreshCtl.endRefreshing()
            case .refreshing:
                page = 1
                refreshCtl.beginRefreshing()
            case .pageEnd:
                spinner.stopAnimating()
                refreshCtl.endRefreshing()
            }
        }
    }
    
    // loadが可能か？
    var isRefreshable: Bool {
        get {
            return loadStatus == .available || loadStatus == .pageEnd
        }
    }
    var isPagiable: Bool {
        get {
            return loadStatus == .available
        }
    }
    
    // 初回load
    public func initialLoadCompletion(data: [T]) {
        if (!hasInitialLoad) {
            listData = data
            hasInitialLoad = true
            reloadData?()
        }
    }
    
    
    // 下端に行って次のページをとってくる処理
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (!isPagiable || pagingCallBack == nil) {
            return
        }
        
        if (hasInitialLoad == false) {
            reloadData?()
            return
        }
        
        let currentOffsetY = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.height
        let distanceToBottom = maximumOffset - currentOffsetY
        if(distanceToBottom < 200) {
            self.loadStatus = .pageLoading
            pagingCallBack?() { [weak self] data, hadError in
                if (hadError) {
                    self?.loadStatus = .available
                    return
                }
                
                if (data.isEmpty) {
                    self?.loadStatus = .pageEnd
                } else {
                    self?.loadStatus = .available
                    self?.listData?.append(contentsOf: data)
                    self?.reloadData?()
                }
            }
        }
    }
    
    // pull to refreshの処理
    @objc func refresh() {
        if (!isRefreshable || refreshCallback == nil) {
            return
        }
        
        loadStatus = .refreshing
        refreshCallback?() { [weak self] data in
            if (data.isEmpty) {
                // 空っぽなのですることない
                self?.listData = data
            } else {
                self?.listData? = data
                
                self?.reloadData?()
                self?.needLifetimeRefresh = false
                
                // timerをresetする
                if let time = self?.lifetime {
                    self?.lifetime = time
                }
            }
            
            self?.loadStatus = .available
        }
    }
    
    // set need lifetime refresh
    @objc func updateLifetimeStatus() {
        needLifetimeRefresh = true
    }
    
    // 画面遷移から戻ってきたときに呼んで、古い情報を更新する
    func lifetimeRefresh() {
        if (!needLifetimeRefresh || loadStatus != .available) {
            return;
        }
        refresh()
    }
}
