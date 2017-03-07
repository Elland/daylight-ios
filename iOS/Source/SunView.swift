import UIKit
import CoreLocation

protocol SunViewDelegate: class {
    func willAnimateWithDuration(_ duration: Double, in sunView: SunView)
}

class SunView: UIView {
    static let sunSize = CGFloat(18.0)
    static let boundingWidth = UIScreen.main.bounds.width - 80
    static let boundingHeight = CGFloat(108)

    weak var delegate: SunViewDelegate?

    var appIsInBackgroundMode = false
    var initialInterfaceUpdate = true

    var percentageInDayOnAppEnterBackground = 0.0
    var percentageInDay = 0.0

    var animationInProgress = false {
        didSet {
            self.currentTimeLabel.alpha = self.animationInProgress == true ? 0 : 1
        }
    }

    var sunPhase = SunPhase.predawn {
        didSet {
            switch self.sunPhase.sky {
            case .dark:
                // reset percentage when it becomes night
                self.percentageInDayOnAppEnterBackground = 0.0
                self.moon.isHidden = false
                self.sunViewLocation = CGPoint(x: (SunView.boundingWidth - SunView.sunSize) / 2.0, y: 0.0)

                if self.initialInterfaceUpdate == true {
                    self.sun.alpha = 1
                }
            case .light:
                self.moon.isHidden = true
            }
        }
    }

    var sunViewLocation = CGPoint(x: 0, y: SunView.boundingHeight) {
        didSet {
            self.setNeedsLayout()

        }
    }

    var sunLeftAnchor: NSLayoutConstraint?
    var sunTopAnchor: NSLayoutConstraint?
    var currentTimeBottomAnchor: NSLayoutConstraint?

    lazy var sunriseLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.light(size: 12)

        return label
    }()

    lazy var sunsetLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.light(size: 12)
        label.textAlignment = .right

        return label
    }()

    lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = Theme.light(size: 12)

        return label
    }()

    lazy var sun: UIImageView = {
        let image = UIImage(named: "sun")!
        let tintImage = image.withRenderingMode(.alwaysTemplate)
        let imageView = UIImageView(image: tintImage)
        imageView.contentMode = .center
        imageView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        imageView.alpha = 0

        return imageView
    }()

    lazy var moon: UIView = {
        let view = UIView()
        view.isHidden = true

        return view
    }()

    lazy var sunMask: UIView = {
        let view = UIView()
        view.clipsToBounds = true

        return view
    }()

    lazy var horizon: UIView = {
        let view = UIView()

        return view
    }()

    lazy var timeFormatter: DateFormatter = {
        let shortTimeFormatter = DateFormatter()
        shortTimeFormatter.dateFormat = "HH:mm"

        return shortTimeFormatter
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.horizon)
        self.addSubview(self.sunriseLabel)
        self.addSubview(self.sunsetLabel)
        self.addSubview(self.sunMask)
        self.sunMask.addSubview(self.sun)
        self.sunMask.addSubview(self.moon)
        self.addSubview(self.currentTimeLabel)

        self.addObservers()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelWidth = CGFloat(35.0)

        self.sunriseLabel.frame = CGRect(x: 0, y: 116, width: labelWidth, height: 16)
        self.sunsetLabel.frame = CGRect(x: self.bounds.width - labelWidth, y: 116, width: labelWidth, height: 16)
        self.sun.frame = CGRect(x: self.sunViewLocation.x, y: self.sunViewLocation.y, width: SunView.sunSize, height: SunView.sunSize)
        self.sunMask.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: SunView.boundingHeight)
        self.horizon.frame = CGRect(x: 0, y: SunView.boundingHeight, width: self.bounds.width, height: 1)
        self.currentTimeLabel.frame = CGRect(x: self.sunViewLocation.x - 10, y: self.sunViewLocation.y - 24, width: labelWidth, height: 16)
        self.moon.frame = CGRect(x: self.sunViewLocation.x + (SunView.sunSize / 2), y: self.sunViewLocation.y, width: SunView.sunSize / 2, height: SunView.sunSize)
    }

    func addObservers() {
        self.removeObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }

    func applicationDidBecomeActive() {
        if self.sunPhase.sky == .light {
            let differenceInPercentage = self.percentageInDay - self.percentageInDayOnAppEnterBackground
            let shouldAnimateFully = differenceInPercentage > 10 || differenceInPercentage <= 0 || self.percentageInDayOnAppEnterBackground == 0.0

            if shouldAnimateFully {
                self.animateFully(toPercentageInDay: CGFloat(self.percentageInDay))
            } else {
                self.animateFrom(percentageInDay: CGFloat(self.percentageInDayOnAppEnterBackground), toPercentageInDay: CGFloat(self.percentageInDay))
            }
        }
    }

    func applicationDidEnterBackground() {
        self.percentageInDayOnAppEnterBackground = self.percentageInDay
    }

    func location(for percentageInDay: CGFloat) -> CGPoint {
        let position = CGFloat.pi + (percentageInDay * CGFloat.pi)
        let x = 50.0 + cos(position) * 50.0
        let y = abs(sin(position) * 100.0)

        let absoluteX = ((SunView.boundingWidth - SunView.sunSize) / 100) * x
        let absoluteY = SunView.boundingHeight - (SunView.boundingHeight / 100.0) * y

        return CGPoint(x: absoluteX, y: absoluteY)
    }

    func animateFrom(percentageInDay fromPercentage: CGFloat, toPercentageInDay percentage: CGFloat) {
        var values = [CGPoint]()
        for index in (Int(fromPercentage * 100)) ... (Int(percentage * 100)) {
            let location = self.location(for: CGFloat(index) / 100.0)
            values.append(location)
        }

        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.values = values
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        animation.delegate = self

        self.animationInProgress = true
        self.sun.layer.add(animation, forKey: "animate position along path")
    }

    func animateFully(toPercentageInDay percentage: CGFloat) {
        var values = [CGPoint]()
        for index in 0 ... (Int(percentage * 100)) {
            let location = self.location(for: CGFloat(index) / 100.0)
            values.append(location)
        }

        let animationDuration = Double(2.0 + (2.0 * percentage))
        let animation = CAKeyframeAnimation(keyPath: "position")

        animation.values = values
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        animation.delegate = self

        self.delegate?.willAnimateWithDuration(animationDuration, in: self)

        self.animationInProgress = true
        self.sun.layer.add(animation, forKey: "animate position along path")
    }

    func updateInterface(location: Location, backgroundColor: UIColor, textColor: UIColor, andPercentageInDay percentageInDay: Double, sunPhase: SunPhase) {
        self.currentTimeLabel.text = self.timeFormatter.string(from: Date())
        self.sunriseLabel.text = location.sunriseTimeString
        self.sunsetLabel.text = location.sunsetTimeString

        self.sunriseLabel.textColor = textColor
        self.sunsetLabel.textColor = textColor
        self.currentTimeLabel.textColor = textColor
        self.horizon.backgroundColor = textColor
        self.sun.tintColor = textColor
        self.moon.backgroundColor = backgroundColor

        self.sunPhase = sunPhase
        self.percentageInDay = percentageInDay

        if self.sunPhase.sky == .light {
            self.setSunPosition(for: self.percentageInDay)
        }

        self.initialInterfaceUpdate = false
    }

    func setSunPosition(for percentageInDay: Double) {
        self.sun.alpha = 1
        self.sunViewLocation = self.location(for: CGFloat(percentageInDay))
    }
}

extension SunView: CAAnimationDelegate {

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            UIView.animate(withDuration: 0.2) {
                self.animationInProgress = false
            }
    }
}
