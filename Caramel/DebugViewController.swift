//
//  DebugViewController.swift
//  Caramel
//
//  Created by James Sun on 2014-11-03.
//  Copyright (c) 2014 Beyond. All rights reserved.
//

import UIKit

class DebugViewController: UIViewController {

    @IBOutlet weak var hrvLabel: UILabel!
    @IBOutlet weak var stressScoreLabel: UILabel!
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var movementLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
