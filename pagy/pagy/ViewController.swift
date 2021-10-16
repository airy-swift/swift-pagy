//
//  ViewController.swift
//  pagy
//
//  Created by Sota Iwahashi on 2021/10/16.
//

import UIKit


class ViewController: UIViewController {
    
    @IBOutlet var table:UITableView!
    
    final let blankView = UIView()
    
    // pagingを管理している
    final let pagyController = Presenter<User>()
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // scroll下端まで行ったとき呼ばれる
        pagyController.pagingCallBack = { [weak self] completion in
            guard let page = self?.pagyController.page else { return }
            
            // data取得処理
            // 疑似apiとして1秒後にデータを取得 & merge
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                
                // 4ページ目以降はpage終了のため読み込まない
                let fetchedList = page > 3 ? [] : [User](repeating: User(name: "airy", age: 24), count: 25)
                
                // 文字通り実質の無限スクロールならこのifはいらない。load後に操作しないとスペース残るし。。
                if fetchedList.isEmpty {
                    self?.table.tableFooterView = self?.blankView
                }
                
                completion(fetchedList, false)
            }
        }
        
        // scroll上端でpullしたとき呼ばれる
        pagyController.refreshCallback = { [weak self] completion in
            // page refresh処理
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                let fetchedList = [User](repeating: User(name: "someone", age: 100), count: 25)
                completion(fetchedList)
                
                self?.table.tableFooterView = self?.pagyController.spinner
            }
        }
        
        // 一定期間でリフレッシュしたい
        pagyController.lifetime = 6 * 60 * 60 // 6時間毎に自動でrefresh
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // paging周りの処理を委譲
        table.delegate = pagyController
        // loadingのUI設定
        table.tableFooterView = pagyController.spinner
        table.refreshControl = pagyController.refreshCtl
        
        pagyController.reloadData = table.reloadData
    }
}



/// MARK - TableViewDataSource
extension ViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let count = pagyController.listData?.count {
            return count
        }
        // throw してもいいと思ふ。
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let label = cell.viewWithTag(1) as! UILabel
        // 読み込んだ新しいデータがUIに反映されたことがわかりやすいようにpage番号をcellに表示する
        if let userData = pagyController.listData?[indexPath.row] {
            label.text = "\(userData.name) : \(userData.age)"
        }
        return cell;
    }

}


/// presenter的な立ち回り
/// viewmodelとかでも可
/// viewから切り離したいねというやつ
class Presenter<T>: PagyController<T>, UITableViewDelegate {
    
    override init() {
        super.init()
        
        // repositoryからとってきてる想定で読んで♡
        // api requestで外部からデータを取得してくる
        // callback内でinitialLoadCompletionを呼ぶ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let fetchedList = [T](repeating: User(name: "initialize", age: 24) as! T, count: 25)
            self?.initialLoadCompletion(data: fetchedList)
        }
    }
    
    // 画面遷移とかするやつ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(lifetime)
        /// FOR TEST
        /// 1秒ごとに自動でreloadする
        lifetime = 1
    }
}



// entity
class User {
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    final let name: String
    final let age: Int
}
