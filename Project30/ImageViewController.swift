//
//  ImageViewController.swift
//  Project30
//
//  Created by TwoStraws on 20/08/2016.
//  Copyright (c) 2016 TwoStraws. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {
    
//3 Let's take a look at one more problem, this time quite subtle. Loading the images was slow because they were so big, and iOS was caching them unnecessarily. But UIImage's cache is intelligent: if it senses memory pressure, it automatically clears itself to make room for other stuff. So why does our app run out of memory?
    
//3 To find another problems, profile the app using Instruments and select the allocations instrument again. This time filter on "imageViewController" and to begin with you'll see nothing because the app starts on the table view. But if you tap into a detail view then go back, you'll see one is created and remains persistent – it hasn't been destroyed. Which means the image it's showing also hasn't been destroyed, hence the massive memory usage.
    
//3 What's causing the image view controller to never be destroyed? If you read through SelectionViewController.swift and ImageViewController.swift you might spot these two things:
    
//3 1. The selection view controller has a viewControllers array that claims to be a cache of the detail view controllers. This cache is never actually used, and even if it were used it really isn't needed.
    
//3 2. The image view controller has a property var owner: SelectionViewController! – that makes it a strong reference to the view controller that created it.
    
//3 The first problem is easily fixed: just delete the viewControllers array and any code that uses it, because it's just not needed. The second problem smells like a strong reference cycle, so you should probably change this: var owner: SelectionViewController! to this:
	weak var owner: SelectionViewController?
	var image: String?
	var animTimer: Timer?
	var imageView: UIImageView?

	override func loadView() {
		super.loadView()
		
		view.backgroundColor = UIColor.black

		// create an image view that fills the screen
		imageView? = UIImageView()
		imageView?.contentMode = .scaleAspectFit
		imageView?.translatesAutoresizingMaskIntoConstraints = false
		imageView?.alpha = 0

		view.addSubview(imageView ?? UIImageView())

		// make the image view fill the screen
		imageView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		imageView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		imageView?.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
		imageView?.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
//4 Run Instruments again and you'll see that the problem is… still there?! The view controllers aren't destroyed because of this line of code:
        
//4 That timer does a hacky animation on the image, and it could easily be replaced with better animations. But even so, why does that cause the image view controllers to never leak?
        
//4 The reason is that when you provide code for your timer to run, the timer holds a strong reference to it so it can definitely be called when the timer is up. We're using self inside our timer’s code, which means our view controller owns the timer strongly and the timer owns the view controller strongly, so we have a strong reference cycle.

		// schedule an animation that does something vaguely interesting
		animTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
			// do something exciting with our image
			self.imageView?.transform = CGAffineTransform.identity

			UIView.animate(withDuration: 3) {
				self.imageView?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
			}
		}
	}

//1 Now, why does the app crash when you go the detail view controller enough times? There are two answers to this question, one code related and one not. For the second question, I already explained that we’re working with supremely over-sized images here – far larger than we actually need.
    
//1 But there's something else subtle here, and it's something we haven't covered yet so this is the perfect time.
    
//1 When you create a UIImage using UIImage(named:) iOS loads the image and puts it into an image cache for reuse later. This is sometimes helpful, particularly if you know the image will be used again. But if you know it's unlikely to be reused or if it's quite large, then don't bother putting it into the cache – it will just add memory pressure to your app and probably flush out other more useful images!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = image?.replacingOccurrences(of: "-Large.jpg", with: "")
        
//1 If you look in the viewDidLoad() method of ImageViewController you'll see this line of code:
        //1 let original = UIImage(named: image)!
        
//2 How likely is it that users will go back and forward to the same image again and again? Not likely at all, so we can skip the image cache by creating our images using the UIImage(contentsOfFile:) initializer instead. This isn't as friendly as UIImage(named:) because you need to specify the exact path to an image rather than just its filename in your app bundle.
        
//2 The solution is to use Bundle.main.path(forResource:ofType:), which is similar to the Bundle.main.url(forResource:) method we’ve used previously, except it returns a simple string rather than a URL:
        guard let path = Bundle.main.path(forResource: image, ofType: nil) else { return }
        guard let original = UIImage(contentsOfFile: path) else { return }

        let renderer = UIGraphicsImageRenderer(size: original.size)

		let rounded = renderer.image { ctx in
            ctx.cgContext.addEllipse(in: CGRect(origin: CGPoint.zero, size: original.size))
			ctx.cgContext.closePath()

            original.draw(at: CGPoint.zero)
		}

		imageView?.image = rounded
    }

    
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		imageView?.alpha = 0

		UIView.animate(withDuration: 3) { [unowned self] in
			self.imageView?.alpha = 1
		}
	}
    
    
//5 There are several solutions here: rewrite the code using smarter animations, use a weak self closure capture list, or destroy the timer when it's no longer needed, thus breaking the cycle. We’re going to take the last option here, to give you a little more practice with invalidating timers – all we need to do is detect when the image view controller is about to disappear and stop the timer.
    
//5 Calling invalidate() on a timer stops it immediately, which also forces it to release its strong reference on the view controller it belongs to, thus breaking the strong reference cycle. If you profile again, you'll see all the ImageViewController objects are now transient, and the app should no longer be quite so crash-prone.
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        animTimer?.invalidate()
    }
    
//6 That being said, the app might still crash sometimes because despite our best efforts we’re still juggling pictures that are far too big. However, the code is at least a great deal more efficient now.

    
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		let defaults = UserDefaults.standard
        var currentVal = defaults.integer(forKey: image ?? "")
		currentVal += 1

        defaults.set(currentVal, forKey:image ?? "")

		// tell the parent view controller that it should refresh its table counters when we go back
        owner?.dirty = true
	}
}
