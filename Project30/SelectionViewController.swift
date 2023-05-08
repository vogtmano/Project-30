//
//  SelectionViewController.swift
//  Project30
//
//  Created by TwoStraws on 20/08/2016.
//  Copyright (c) 2016 TwoStraws. All rights reserved.
//

import UIKit

//0 The app shows a table view containing garish images of popular internet acronyms.

//0 When one of the rows is tapped, a detail view controller appears, showing the image at full size. Every time you tap on the big image, it adds one to a count of how many times that image was tapped, and that count is shown in the original view controller. That’s it – that's all the app does.

//0 And how bad are the problems? Well, if you run the app on a device, you'll probably find that it crashes after you’ve viewed several pictures.

//0 You might also notice that scrolling isn’t smooth in the table view, particularly on older devices. If you scroll around a few times iOS might be able to smooth the scrolling a little, but you’ll certainly struggle to get it a flawless 60 frames per second on iPhone, or 120 frames per second on iPad Pro – the gold standard for iOS drawing.

//0 I hope you’ve never seen an app that manages to have all these problems at the same time, but I can guarantee you’ve seen apps that have one or two at a time. The goal of this project is to help you learn the skills needed to identify, fix, and test solutions to these common problems.

class SelectionViewController: UITableViewController {
	var items = [String]() // this is the array that will store the filenames to load
	var dirty = false

    override func viewDidLoad() {
        super.viewDidLoad()

		title = "Reactionist"

		tableView.rowHeight = 90
		tableView.separatorStyle = .none
        
//7 The other solution of creating table view cells in code is to register a class with the table view for the reuse identifier "Cell".
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

		// load all the JPEGs into our array
		let fm = FileManager.default

        if let tempItems = try? fm.contentsOfDirectory(atPath: Bundle.main.resourcePath ?? "") {
			for item in tempItems {
				if item.range(of: "Large") != nil {
					items.append(item)
				}
			}
		}
    }

    
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if dirty {
			// we've been marked as needing a counter reload, so reload the whole table
			tableView.reloadData()
		}
	}

    // MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return items.count * 10
    }

//6 The allocations instrument has told me how many of the objects are persistent (created and still exist (trwały)) and how many are transient (created and since destroyed (przejściowy)). I noticed how just swiping around has created a large number of transient UIImageView and UITableViewCell objects (a lot).
    
//6 This is happening because each time the app needs to show a cell, it creates it then creates all the subviews inside it – namely an image view and a label, plus some hidden views we don’t usually care about. iOS works around this cost by using the method dequeueReusableCell(withIdentifier:), but if you look at the cellForRowAt method you won’t find it there. This means iOS is forced to create a new cell from scratch, rather than re-using an existing cell. This is a common coding mistake to make when you're not using storyboards and prototype cells, and it's guaranteed to put a speed bump in your apps.

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
//6 That's the only place where table view cells are being created, so clearly it's the culprit because it creates a new cell every time the table view asks for one. This has been slow since the very first days of iOS development, and Apple has always had a solution: ask the table view to dequeue a cell, and if you get nil back then create a cell yourself.

//6 This is different from when we were using prototype cells with a storyboard. With storyboards, if you dequeue a prototype cell then iOS automatically handles creating them as needed.
        
    // let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")

//6 If you're creating table view cells in code, you have two options to fix this intense allocation of views. First, you could rewrite the above line to be this:
        
    // var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: "Cell")
        
    // if cell == nil {
    //    cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
    // }
        
//6 That dequeues a cell, but if it gets nil back then we create one. Note the force unwrapped optional at the end of the first line – we’re saying that cell might initially be empty, but it will definitely have a value by the time it’s used.
        
        
//7 The other solution you could use is to register a class with the table view for the reuse identifier "Cell".
        
//7 After registering of the UITableViewCell class in viewDidLoad() we can use our usual method dequeuing table view cells inside cellForRowAt:
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
//8 With this approach, you will never get nil when dequeuing a cell with the identifier "Cell". As with prototype cells, if there isn't one to dequeue a new cell will be created automatically.
        
//8 The second solution is substantially newer than the first and can really help cut down the amount of code you need. But it has two drawbacks (wady): with the first solution you can specify different kinds of cell styles than just .default, not least the .subtitle option we used in project 7; also, with the first solution you explicitly know when a cell has just been created, so it's easy to force any one-off work into the if cell == nil { block.

//8 Regardless of which solution you chose, you should be able to run the allocations instrument again and see far fewer table view cell allocations. With this small change, iOS will just reuse cells as they are needed, which makes your code run faster and operate more efficiently.

		
        // find the image for this cell, and load its thumbnail
		let currentImage = items[indexPath.row % items.count]
		let imageRootName = currentImage.replacingOccurrences(of: "Large", with: "Thumb")
        
        guard let path = Bundle.main.path(forResource: imageRootName, ofType: nil) else { return UITableViewCell() }
        guard let original = UIImage(contentsOfFile: path) else { return UITableViewCell() }
        
//1 Important: when making performance changes you should change only one thing at a time, then re-test to make sure your change helped. If you changed two or more things and performance got better, which one worked? Or, if performance got worse, perhaps one thing worked and one didn't!
        
//1 Let's begin with the table view: you should have seen parts of the table view turn dark yellow when Color Offscreen-Rendered Yellow was selected. This is happening because the images are being rendered inefficiently: the rounded corners effect and the shadow are being done in real-time, which is computationally expensive.
        
//1 There are two new techniques being demonstrated here: creating a clipping path and rendering layer shadows.
        
//1 The rendering here is made up of three commands: adding an ellipse and drawing a UIImage (both things you’ve seen before), but the call to clip() is new. As you know, you can create a path and draw it using two separate Core Graphics commands, but instead of running the draw command you can take the existing path and use it for clipping instead. This has the effect of only drawing things that lie inside the path, so when the UIImage is drawn only the parts that lie inside the elliptical clipping path are visible, thus rounding the corners.
        
        
        //3 To deliver huge performance increases, first we need to change the rendering code.
        let renderRect = CGRect(origin: .zero, size: CGSize(width: 90, height: 90))
        let renderer = UIGraphicsImageRenderer(size: renderRect.size)

		let rounded = renderer.image { ctx in
			ctx.cgContext.addEllipse(in: renderRect)
			ctx.cgContext.clip()

            original.draw(in: renderRect)
            
        //3 That still causes iOS to load and render a large image, but it now gets scaled down to the size it needs to be for actual usage, so it will immediately perform faster.
		}

		cell.imageView?.image = rounded
        
//2 The second new technique in this code is rendering layer shadows. iOS lets you add a basic shadow to any of its views, and it's a simple way to make something stand out on the screen. But it's not fast: it literally scans the pixels in the image to figure out what's transparent, then uses that information to draw the shadow correctly.
        
//2 The combination of these two techniques creates a huge amount of work for iOS: it has to load the initial image, create a new image of the same size, render the first image into the second, then render the second image off-screen to calculate the shadow pixels, then render the whole finished product to the screen. When you hit a performance problem, you either drop the code that triggers the problem or you make it run faster.
        
//2 The problem is that the images being loaded are 750x750 pixels at 1x resolution, so 1500x1500 at 2x, and 2250x2250 at 3x. If you look at viewDidLoad() you’ll see that the row height is 90 points, so we’re loading huge pictures into a tiny space. That means loading a 1500x1500 image or larger, creating a second render buffer that size, rendering the image into it, and so on.
        
//2 We’re squeezing very large images into a tiny space. iOS doesn’t know or care that this is happening because it just does what its told, but we have more information: we know the image isn’t needed at that crazy size, so we can use that knowledge to deliver huge performance increases.

		// give the images a nice shadow to make them look a bit more dramatic
		cell.imageView?.layer.shadowColor = UIColor.black.cgColor
		cell.imageView?.layer.shadowOpacity = 1
		cell.imageView?.layer.shadowRadius = 10
		cell.imageView?.layer.shadowOffset = CGSize.zero
        
//4 However, it still incurs a second rendering pass: iOS still needs to trace the resulting image to figure out where the shadow must be drawn. Calculating the shadow is hard, because iOS doesn’t know that we clipped it to be a circle so it needs to figure out what's transparent itself. Again, though, we have more information: the shadow is going to be a perfect circle, so why bother having iOS figure out the shadow for itself?
        
//4 We can tell iOS not to automatically calculate the shadow path for our images by giving it the exact shadow path to use. The easiest way to do this is to create a new UIBezierPath that describes our image (an ellipse with width 90 and height 90), then convert it to a CGPath because CALayer doesn't understand what UIBezierPath is.
        cell.imageView?.layer.shadowPath = UIBezierPath(ovalIn: renderRect).cgPath
        
//4 When you run that, you'll still see the same shadows everywhere, but the dark yellow color is gone. This means we’ve successfully eliminated the second render pass by giving iOS the pre-calculated shadow path, and we’ve also sped up drawing by scaling down the amount of working being done.

//5 Working with rounded corners and shadows can be tricky, as you’ve seen here. If it weren’t for the shadowing, we could eliminate the first render pass by setting layer.cornerRadius to have iOS round the corners for us – it’s a nice and easy way to create rounded rectangle shapes (or even circles!) without any custom rendering code.
		
        // each image stores how often it's been tapped
		let defaults = UserDefaults.standard
		cell.textLabel?.text = "\(defaults.integer(forKey: currentImage))"

		return cell
    }

    
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let vc = ImageViewController()
		vc.image = items[indexPath.row % items.count]
		vc.owner = self

		// mark us as not needing a counter reload when we return
		dirty = false

		navigationController?.pushViewController(vc, animated: true)
	}
}
