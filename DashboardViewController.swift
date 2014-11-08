//
//  DashboardViewController.swift
//  Caramel
//
//  Created by James Sun on 2014-11-02.
//  Copyright (c) 2014 Beyond. All rights reserved.
//

import UIKit

class DashboardViewController: UIViewController {
    
    var hrBluetooth: HRBluetooth!
    var dashboardCallback: DashboardCallback!
    
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var dayOfTheWeekLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var lastEventDurationLabel: UILabel!
    @IBOutlet weak var lastEventTimeLabel: UILabel!
    
    @IBOutlet weak var dailyOverallLabel: UILabel!
    @IBOutlet weak var currentScoreLabel: UILabel!
    @IBOutlet weak var lastStressLabel: UILabel!
    
    @IBOutlet var profileCircleView: ProfileCircleView!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.hrBluetooth = HRBluetooth()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController!.navigationBar.titleTextAttributes = [ NSFontAttributeName: UIFont(name: "Univers-Light-Bold", size: 18)!]
        
        self.displayUpdateDateLabels()
        self.updateProfile()

        self.dashboardCallback = DashboardCallback(updatedScoreCallback)
        self.hrBluetooth.startScanningHRPeripheral(self.dashboardCallback.newHeartRateCallback)
        
        println("Loaded DashboardViewController view!")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func refreshButtonDidPress(sender: AnyObject) {
        self.hrBluetooth.startScanningHRPeripheral(self.dashboardCallback.newHeartRateCallback)
        println("Restarted Bluetooth services")
    }
    
    private func displayUpdateDateLabels() {
        let dateFormatter = NSDateFormatter()
        let currentDate = NSDate()
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE")
        self.dayOfTheWeekLabel.text = dateFormatter.stringFromDate(currentDate).uppercaseString
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMM d, yyyy")
        self.dateLabel.text = dateFormatter.stringFromDate(currentDate).uppercaseString
    }
    
    private func updatedScoreCallback(interval: StressScoreInterval!) {
        println("Smooth score: \(interval.score)")
        
        dispatch_async(dispatch_get_main_queue(), {
            self.currentScoreLabel.text = String(interval.score)
        })
        
        Database.addStressScoreInterval(interval)
        
        self.updateProfile()
        
        self.possiblySendNotification(interval.score)
    }
    
    private func possiblySendNotification(score: Int!) {
        println("Determining whether to send a notification or not")
        if score < Constants.getStressNotificationThreshold() {
            return
        }
        let lastMovementDate: NSDate? = Timer.getLastMovementDate()
        let lastLowDate: NSDate? = Timer.getLastLowStressNotifDate()
        let lastHighDate: NSDate? = Timer.getLastHighStressNotifDate()
        let currentDate = NSDate()
        
        // don't send notification if movement too recent
        if lastMovementDate != nil {
            let timeDifference = currentDate.timeIntervalSinceDate(lastMovementDate!)
            if timeDifference < NSTimeInterval(Constants.getMovementAffectiveDuration()) {
                return
            }
        }
        
        if lastLowDate == nil {
            Notification.sendLowStressNotification()
            Timer.setLastLowStressNotifDate(currentDate)
            Database.addNotificationRecord(NotificationRecord(type: "low", date: currentDate, userID: User.getUserID()))
        } else {
            let lowTimeDifference = currentDate.timeIntervalSinceDate(lastLowDate!)
            if lowTimeDifference < NSTimeInterval(Constants.getStressNotificationIntervalDuration()) {
                return
            } else {
                let highTimeDifference = currentDate.timeIntervalSinceDate(lastHighDate!)
                if highTimeDifference < NSTimeInterval(Constants.getStressNotificationIntervalDuration()) {
                    Notification.sendLowStressNotification()
                    Timer.setLastLowStressNotifDate(currentDate)
                    Database.addNotificationRecord(NotificationRecord(type: "low", date: currentDate, userID: User.getUserID()))
                } else {
                    Notification.sendHighStressNotification()
                    Timer.setLastHighStressNotifDate(currentDate)
                    Database.addNotificationRecord(NotificationRecord(type: "high", date: currentDate, userID: User.getUserID()))
                }
            }
        }
    }
    
    private func updateProfile() {
        println("Updating profile circle and daily score")
        let currentDate = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.CalendarUnitYear | .CalendarUnitMonth | .CalendarUnitDay, fromDate: currentDate)
        var startDate = calendar.dateFromComponents(components)!
        var endDate = startDate.dateByAddingTimeInterval(60 * 60 * 24) //add 24hrs
        
        let stressIntervals = Database.getSortedStressIntervals(startDate, endDate: endDate)
        let notifRecords = Database.getSortedNotificationRecords(startDate, endDate: endDate)

        //updates current and lastStress scores
        self.displayCurrentAndLastStressScores(stressIntervals)
        
        //updates profile circle
        let scores = self.prepareStressScoresForCircle(startDate, endDate: endDate, stressIntervals: stressIntervals)
        self.profileCircleView.setStressScores(scores)
        self.profileCircleView.setNeedsDisplay()
        
        //updates daily score
        self.displayDailyScore(stressIntervals, notifRecords: notifRecords)
    }
    
    private func displayCurrentAndLastStressScores(stressIntervals: [StressScoreInterval]) {
        if stressIntervals.count == 0 {
            return
        }
        var lastStressDuration = 0
        var updatedStressLabel = false
        for var i = stressIntervals.count - 1; i >= 0; i-- {
            if stressIntervals[i].score >= Constants.getStressNotificationThreshold() {
                lastStressDuration += 30
                if !updatedStressLabel {
                    updatedStressLabel = true
                    dispatch_async(dispatch_get_main_queue(), {
                        self.lastStressLabel.text = "\(String(stressIntervals[i].score) )%"
                        self.lastEventTimeLabel.text = Conversion.dateToTimeString(stressIntervals[i].endDate)
                    })
                }
            } else {
                if updatedStressLabel {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.lastEventDurationLabel.text = "\(lastStressDuration) s"
                    })
                    return
                }
            }
        }
        if updatedStressLabel {
            dispatch_async(dispatch_get_main_queue(), {
                self.lastEventDurationLabel.text = "\(lastStressDuration) s"
            })
            return
        }
    }
    
    private func prepareStressScoresForCircle(startDate: NSDate!, endDate: NSDate!, stressIntervals: [StressScoreInterval]) -> [Int?] {
        println("Calculating circle update array")
        var result = [Int?]()
        let circleArcRange = NSTimeInterval(Constants.getProfileCircleFineness() * 60)
        var index = 0
        var currentStartDate = startDate
        while currentStartDate.compare(endDate) == NSComparisonResult.OrderedAscending {
            //we take the maximum over that range as the display
            let currentEndDate = currentStartDate.dateByAddingTimeInterval(circleArcRange)
            var maxScore: Int?
            //we want start <= scoreStartDate < end
            while index < stressIntervals.count &&
                currentStartDate.compare(stressIntervals[index].startDate) != NSComparisonResult.OrderedDescending &&
                currentEndDate.compare(stressIntervals[index].startDate) == NSComparisonResult.OrderedDescending {
                    if maxScore == nil {
                        maxScore = stressIntervals[index].score
                    } else {
                        maxScore = max(maxScore!, stressIntervals[index].score)
                    }
                    index++
            }
            result.append(maxScore)
            currentStartDate = currentEndDate
        }
        return result
    }

    private func displayDailyScore(stressIntervals: [StressScoreInterval], notifRecords: [NotificationRecord]) {
        println("Calculating and displaying daily overall score")
        if stressIntervals.count == 0 {
            return
        }
        var score = 0.0
        var stressScores = [Int]()
        var lowNotifCount = 0
        var highNotifCount = 0
        for interval in stressIntervals {
            stressScores.append(interval.score)
        }
        for record in notifRecords {
            if record.type == "low" {
                lowNotifCount++
            } else {
                highNotifCount++
            }
        }

        score += Math.stddev(stressScores) / 30.0 * 25.0
        score += Double(lowNotifCount) / 6.0 * 25.0
        score += Double(highNotifCount) / 3.0 * 25.0
        score += Math.rms(stressScores) / 100.0 * 25.0
        score = min(99.0, score)
        score = max(1.0, score)
        var wellnessScore = Int(100.0 - score)
        self.dailyOverallLabel.text = String(wellnessScore)
    }
}