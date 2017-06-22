macro "morphFilter"{
	title = getTitle();
	setBatchMode(true);
	for(s=1;s<=nSlices;s++){
		setSlice(s);
		run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=2");
		if(s==1){
			rename("aa");
		} else {
			rename(s);
			run("Concatenate...", "  title=aa image1=aa image2=&s image3=[-- None --]");
		}
		selectWindow(title);
	}
	setBatchMode("Exit and show");
}

macro "compositeLCI"{
	// Create composite for LCI sparse label
	workDir = getDirectory("Select Movie folder");
	workFile = getFileList(workDir);
	setBatchMode(true);
	for (o = 0; o < workFile.length; o++){
		bOver = indexOf(workFile[o], "overview") >= 0;
		if (bOver){
			if (endsWith(workFile[o], ".stk")){
				tempOver = workFile[o];
				overFile = workDir + "\\" + tempOver;
				open(overFile);
				run("Make Composite", "display=Composite");
				run("Grays");
				run("Next Slice [>]");
				run("Magenta");
				run("Save");
				close();
			}
		}
	}
	setBatchMode(false);
}

macro "stackFromSingle"{
	// Create stack from single image
	run("Select All");
	run("Copy");
	Dialog.create("Frame to stack");
	Dialog.addNumber("Number of frames:", 181);
	Dialog.show();
	nF = Dialog.getNumber();
	s = 1;
	while (s < nF){
		run("Add Slice");
		run("Paste");
		s ++;
	}
}

macro "clockDCV"{
	// Clock Creator for DCV stimulation
	Dialog.create("DCV clock");
	Dialog.addNumber("Image frequency (Hz)", 2);
	Dialog.addNumber("Number of pulses", 8);
	Dialog.addNumber("Stimulation start (s)", 30);
	Dialog.show();
	imFreq = Dialog.getNumber();
	nPulses = Dialog.getNumber();
	stimStart = Dialog.getNumber();
	getDimensions(width, height, channels, slices, frames);
	setBatchMode(true)
	if(slices > frames){
		nF = slices - 1;
	} else {
		nF = frames - 1;
	}
	time = nF+1;
	scaleF = 2 / imFreq;
	newImage("Clock", "RGB black", (nF + 20) * scaleF, 20, time);
	setForegroundColor(255, 255, 255);
	makeRectangle(2, 2, (nF + 2) * scaleF, 16);
	run("Draw", "stack");
	setForegroundColor(0, 255, 255);
	stimStart = stimStart * scaleF + 1;
	for(s=0; s<nPulses; s++){
		makeRectangle(2+stimStart+(3*s), 3, 2, 15);
		run("Fill", "stack");
	}
	setForegroundColor(255, 0, 255);
	nP = 3;
	sT = 2/imFreq;
	for(p = 1; p <= time; p++){
		Stack.setSlice(p);
		makeRectangle(nP, 3, sT, 15);
		run("Fill", "frame");
		nP += sT;
	}
	run("Select None");
	run("Scale...", "x=- y=- z=1.0 width=" + width + " height=20 depth=" + time + " interpolation=Bilinear average process create");
	selectWindow("Clock");
	close();
	selectWindow("Clock-1");
	rename("Clock");
	setForegroundColor(255, 255, 255);
	run("Label...", "format=00:00 starting=0 interval=" + imFreq + " x=" + width - 27 + " y=17 font=10 text=[] range=1-" + time);
	setBatchMode("Exit and show");
	//run("Resize", "sizex=" + width + " sizey=20.0 method=Least-Squares interpolation=Cubic unitpixelx=true unitpixely=true");
}

macro "downsampleTimeStack"{
	setBatchMode(true);
	// ask for batch conversion
	bBatch = getBoolean("Batch processing?");
	if(bBatch){
		// ask for pattern
		Dialog.create("Pattern name");
		Dialog.addString("Name: ", "StimArr");
		Dialog.show();
		nameP = Dialog.getString();
		workDir = getDirectory("Choose directory");
		// get the list of files
		workFile = getFileList(workDir);
		// loop through all the file: check nameP
		for (n = 0; n < workFile.length; n++){
			bName = indexOf(workFile[n], nameP) >= 0;
			bZip = endsWith(workFile[n], "zip");
			bTrue = bName & !bZip;
			if(bName){
				tempFile = workFile[n];
				openFile = workDir + "\\" + tempFile;
				open(openFile);
				oriTitle = getTitle();
				downsample();
				selectWindow(oriTitle);
				close();
				selectWindow("Downsampled");
				rename(oriTitle);
				if(File.exists(workDir + "\\Downsampled\\")){
					saveAs("Tiff", workDir + "\\Downsampled\\" + oriTitle);
				} else {
					File.makeDirectory(workDir + "\\Downsampled\\");
					saveAs("Tiff", workDir + "\\Downsampled\\" + oriTitle);
				}
			}
		}
		setBatchMode(false);
	} else {
		downsample();
		setBatchMode("Exit and show");
	}

	function downsample(){
		// Downsample stack
		setPasteMode("Add");
		title = getTitle();
		getDimensions(width, height, frames, slices, channels);
		newImage("Downsampled", "16-bit black", 512, 512, floor(slices/2)+1);
		dS = 1;
		for(s=1; s<=slices; s++){
			selectWindow(title);
			setSlice(s);
			run("Select All");
			run("Copy");
			selectWindow("Downsampled");
			if(s%2 > 0){
				setSlice(dS);
			} else {
				setSlice(dS);
				dS += 1;
			}
			run("Paste");
			if (s == slices){
				selectWindow(title);
				setSlice(s);
				run("Select All");
				run("Copy");
				selectWindow("Downsampled");
				run("Paste");
			}
		}
	}
}

macro "openRoiSetOf"{
oriTitle = getTitle();
workDir = getDirectory("Image");
workFile = getFileList(workDir);
getDimensions(width, height, channels, slices, frames);
if(channels>1){
	run("Split Channels");
	selectWindow("C1-" + oriTitle);
	close();
	selectWindow("C2-" + oriTitle);
	rename(oriTitle);
}
for (o = 0; o < workFile.length; o++){
	showProgress(o/workFile.length);
	bZip = endsWith(workFile[o], ".zip");
	bName = indexOf(workFile[o], substring(oriTitle,0,lengthOf(oriTitle)-4)) >= 0;
	bOpen = bZip && bName;
	if(bOpen){
		roiManager("Open",  workDir + "\\" + workFile[o]);
		o = workFile.length;
	}
}
}

macro "bleachCorrection"{
setBatchMode(true);
// get the directories
workDir = getDirectory("Select Movie folder");
saveDir = getDirectory("Select Saving folder");
// get the list of files
workFile = getFileList(workDir);
// loop through all the file: tiff
name = getString("Look for?", "treated");
for (o = 0; o < workFile.length; o++){
	bOver = indexOf(workFile[o], "Stim") >= 0;
	
	bSomething = bOver | indexOf(workFile[o], name) >= 0;
	if (bSomething){
		tempOver = workFile[o];
		overFile = workDir + "\\" + tempOver;
		open(overFile);
		overTitle = getTitle();
		run("Bleach Correction", "correction=[Histogram Matching]");
		saveTitle = getTitle();
		saveAs("Tiff", saveDir + "\\" + saveTitle);
		while(nImages > 0){
			close();
		}
	}
}
setBatchMode(false);
}

macro "frameShiftCorrection"{
/*
bCont = true;
while (bCont){
	waitForUser("Align frame?");
	Dialog.create("Frame shift correct");
	Dialog.addNumber("Pixel onset", 1);
	Dialog.show;
	pxOns = Dialog.getNumber();
	makeRectangle(512-pxOns, 0, pxOns, 512);
	run("Copy");
	run("Select None");
	run("Translate...", "x=" + pxOns + " y=0 interpolation=None slice");
	makeRectangle(0, 0, pxOns, 512);
	run("Paste");
	run("Select None");
	bCont = getBoolean("Do you wish to continue?");
}
*/
//New version
	setPasteMode("Copy");
 	alt=8;
	title = getTitle();
	makeLine(508, 0, 512, 0);
	run("Multi Kymograph", "linewidth=1");
	rename("Frame observer");
	selectWindow(title);
	run("Select None");
	selectWindow("Frame observer");
	while(isOpen("Frame observer")){
		getCursorLoc(x, y, z, flag);
		if(isKeyDown("alt")){
			selectWindow(title);
			setSlice(y+1);
			pxOns = 4 - x;
			makeRectangle(512-pxOns, 0, pxOns, 512);
			run("Copy");
			run("Select None");
			run("Translate...", "x=" + pxOns + " y=0 interpolation=None slice");
			makeRectangle(0, 0, pxOns, 512);
			run("Paste");
			run("Select None");
		}
	}
}

macro "detectParticleLSM"{
	// Get the main Directory
path = getDirectory("Select Working directory");
path_list = getFileList(path);
nfile     = path_list.length;
setBatchMode(true);
// Loop through all the file
for (f = 0; f < nfile; f++){
	f_path = path + path_list[f];
	if (endsWith(f_path, ".tif")) {
		open(f_path);
		title = getTitle();
		selectWindow(title);
		run("Duplicate...", "duplicate channels=3");
		selectWindow(title);
		close();
		rename(title);
		run("Detect Particles", "approximate=10 sensitivity=[Bright particles (SNR=5)]");
		run("To ROI Manager");
		roiManager("Save", path + "RoiSet_" + title + ".zip");
		roiManager("Delete");
		while(nImages > 0){
			close();
		}
}
setBatchMode(false);
}


macro "dualColorStreamMetamorph"{
	// Split dual color Stream Meta-morph

	// Create a dialog for the informations
	Dialog.create("Dual-color Stream");
	Dialog.addChoice("Red frames", newArray("Evens", "Odds"));
	Dialog.addChoice("Green frames", newArray("Evens", "Odds"));
	Dialog.addCheckbox("Process folder", true);
	Dialog.show;
	redFrames = Dialog.getChoice();
	greenFrames = Dialog.getChoice();
	bFolder = Dialog.getCheckbox();
	
	if (bFolder){
		workDir = getDirectory("Select working folder");
		workList = getFileList(workDir);
		nFile = workList.length;
		setBatchMode(true);
		for (f = 0; f < nFile; f++){
			fPath = workDir + workList[f];
			if (endsWith(fPath, ".stk")){
				showProgress(f+1, nFile);
				open(fPath);
				title = getTitle();
				splitDualColor(title, redFrames, greenFrames);
				saveAs("Tiff", workDir + "/dual" + title);
				close();
			}
		}
		setBatchMode(false);
	} else {
		title = getTitle();
		workDir = getDirectory("image");
		splitDualColor(title, redFrames, greenFrames);
		saveAs("Tiff", workDir + "/dual" + title);
	}
	
	///////////////////////////////////////////////////////////////////////////////////////////////
	function splitDualColor(title, redFrames, greenFrames){
		subTitle = substring(title, 0, lengthOf(title) - 4);
		newTitle = subTitle + "dual";
		// red
		if (matches(redFrames, "Evens")){
			red = 2;
		} else {
			red = 1;
		}
		run("Make Substack...", " slices=" + red + "-" + nSlices + "-2");
		rename("redChannel");
		// green
		if (matches(greenFrames, "Evens")){
			green = 2;
		} else {
			green = 1;
		}
		selectWindow(title);
		run("Make Substack...", " slices=" + green + "-" + nSlices + "-2");
		rename("greenChannel");
		// merge
		run("Merge Channels...", "c1=redChannel c2=greenChannel create ignore");
		selectWindow("Composite");
		rename(newTitle);
		close(title);
	}	
}

macro "navigateROI"{
	title = getTitle();
nROI = roiManager("count");
roiSelect = 0;
selectRoi(title, roiSelect);
bCont = true;
while (bCont){
	waitForUser("ROI: " + roiSelect + 1 + " / " + nROI + "\n"
		+ "\"OK\" to move forward;\n"
		+ "\"Alt + OK\" to navigate backward;\n"
		+ "\"Shift + OK\" to focus the selection;\n"
		+ "\"Esc\" to stop.");
	if (isKeyDown("alt")){
		if(roiSelect == 0){
			roiSelect = nROI-1;
		} else {
			roiSelect -= 1;
		}
		selectRoi(title, roiSelect);
	} else if(isKeyDown("shift")) {
		selectRoi(title, roiSelect);
	} else {
		if(roiSelect == nROI-1){
			roiSelect = 0;
		} else {
			roiSelect += 1;
		}
		selectRoi(title, roiSelect);
	}
}

function selectRoi(title, roiSelect){
	selectWindow(title);
	roiManager("Select", roiSelect);
	run("To Selection");
	run("Out [-]");
	run("Out [-]");
	run("Out [-]");
	run("Out [-]");
}

}


macro "plotROIsFrame"{
	Dialog.create("What to plot?");
	Dialog.addChoice("What plot?",newArray("Histogram","Cumulative"));
	Dialog.show;
	wtp = Dialog.getChoice;
	nRoi = roiManager("Count");
	zPos = newArray(nRoi);
	
	for(r=0;r<nRoi;r++){
		roiManager("Select",r);
		zPos[r] = getSliceNumber();
	}
	zPos = Array.sort(zPos);
	xVal = newArray(241);
	histC = newArray(241);
	cumC =  newArray(241);
	
	for(z=0;z<241;z++){
		histN = 0;
		for(r=0;r<nRoi;r++){
			if(zPos[r]==z){
				histN+=1;
			}
		}
		histC[z] = histN;
		xVal[z] = z+1;
		if(z==0){
			cumC[z] = histC[z];
		}else{
			cumC[z] = cumC[z-1] + histC[z];
		}
	}
	if(wtp=="Histogram"){
		Plot.create("ROI time (histogram)", "Frame", "Number of ROIs", xVal, histC);
	}else{
		Plot.create("ROI time (cumulative)", "Frame", "Number of ROIs", xVal, cumC);
	}
}

macro "navigateCanvas"{
	bCont = true;
	while(bCont){
	waitForUser("move to next quadrant?");
	run("Select None");
	getDisplayedArea(x,y,w,h);
	zoom = getZoom()*100;
	if(x+w<512){
		xC = x+(w*3/2);
		yC = y+h/2;
	}
	if(x+w>=512){
		if(y+h>=512){
			xC = w/2;
			yC = h/2;
		} else{
			xC = w/2;
			yC = y+(h*3/2);
		}
	}	
	run("Set... ", "zoom="+zoom+" x="+xC+" y="+yC+" width="+w+" height="+h);
	}
}

macro "ROIcolocalization"{
	// Get the main Directory
	firstDir = getDirectory("Select first folder");
	secondDir  = getDirectory("Select second folder");
	firstFile = getFileList(firstDir);
	nFirst = firstFile.length;
	secondFile = getFileList(secondDir);
	nSecond = firstFile.length;
	setForegroundColor(255, 255, 255);
	for(f=0;f<nFirst;f++){
		newImage("Untitled", "8-bit black", 512, 512, 1);
		firstPath = firstDir + firstFile[f];
		roiManager("Open", firstPath);
		roiManager("Fill");
		run("Options...", "iterations=1 count=1 black do=Nothing");
		//run("Dilate");
		roiManager("Deselect");
		roiManager("Delete");
		for(s=0;s<nSecond;s++){
			if(matches(secondFile[s], firstFile[f])){
				secondPath = secondDir + secondFile[s];
				roiManager("Open", secondPath);
				nRoi = roiManager("Count");
				tempM = newArray(nRoi);
				for(r=0;r<nRoi;r++){
					roiManager("Select",r);
					getStatistics(area, mean, min, max, std, histo);
					tempM[r] = mean;
				}
				print(secondFile[s]);
				Array.print(tempM);
			}
			if(roiManager("count") > 0){
				roiManager("Deselect");
				roiManager("Delete");
			}
		}
		while(nImages > 0){
			close();
		}
	}
}

macro "synapticArea"{
	workDir = getDirectory("Select Images folder");
	saveDir = getDirectory("Select Saving folder");
	workFile = getFileList(workDir);
	nFile = workFile.length;
	setBatchMode(true);
	for(f=0;f<nFile;f++){
		showProgress(f/nFile);
		filePath = workDir + workFile[f];
		bSyn = indexOf(workFile[f], "_synapses") > 0;
		if(bSyn){
			open(filePath);
			title = getTitle();
			sTitle = substring(title,0,lengthOf(title)-4);
			run("Duplicate...", " ");
			run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=2");
			rename("WTH");
			setAutoThreshold("Default dark");
			setAutoThreshold("Moments dark");
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Dilate");
			run("Create Selection");
			roiManager("Add");
			while(nImages > 0){
				close();
			}
			roiManager("Save", saveDir+sTitle+".zip");
			roiManager("Delete");
		}
	}
	setBatchMode(false);
}

macro "synapsesNumber"{
	workDir = getDirectory("Select Roi folder");
	imgDir = getDirectory("Select Images folder");
	workFile = getFileList(workDir);
	imgFile = getFileList(imgDir);
	nFile = workFile.length;
	nImg = imgFile.length;
	setBatchMode(true);
	for(f=0;f<nFile;f++){
		showProgress(f/nFile);
		filePath = workDir + workFile[f];
		bSyn = indexOf(workFile[f], "_synapses") > 0;
		if(bSyn){
			title = substring(workFile[f],0, lengthOf(workFile[f]) - 4);
			roiManager("Open", filePath);
			newImage(workFile[f], "8-bit black", 512, 512, 1);
			run("Set Scale...", "distance=1 known=0.4 unit=um global");
			roiManager("Fill");
			run("Watershed");
			for(i=0;i<nImg;i++){
				bStk = endsWith(imgFile[i], ".stk");
				imTitle = substring(workFile[f],0, lengthOf(imgFile[i]) - 4);
				bName = matches(imTitle, title);
				if(bStk&bName){
					open(imgDir + imgFile[i]);
					run("Set Measurements...", "area mean redirect="+ imgFile[i] +" decimal=3");
					selectWindow(workFile[f]);
					run("Analyze Particles...", "summarize");
					i = nImg;
				}
			}
			roiManager("Delete");
			while(nImages > 0){
				close();
			}
		}
	}
	setBatchMode(false);
}

macro "convert nd2 sequence"{
	// Get the main Directory assuming there is a folder per sequence
	workDir = getDirectory("Select main diretory");
	workFold = getFileList(workDir);
	nFold = workFold.length;

	// ask for a saving string
	saveTitle = getString("Enter file name (sequence)", "date_cond");

	// considering the name of the folder with information for coverslip
	setBatchMode(true);
	for(d=0; d<nFold; d++){
		showStatus("Converting nd2 sequences");
		showProgress(d/nFold);
		workF = workDir + workFold[d];
		workFiles = getFileList(workF);
		nFile = workFiles .length;
		for(f=0; f<nFile; f++){
			tempFile = workF + workFiles[f];
			if(endsWith(tempFile, "nd2")){
			
				// open nd2 sequences with Bio-Format, all images at one
				run("Bio-Formats Importer", "open=" + tempFile + " autoscale color_mode=Default open_all_series rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");

				// get information for saving (save in the same folder)
				savePath = getDirectory("image");
			
				// considering the nd2 sequences are usually "Seq####.nd2 - Seq####.nd2 (series n)
				seq = IJ.pad(f,4); // to have the sequence number
				n = 1; // series number
				nImg = nImages; // total number of images
				while(n <= nImg){
					nn = n;
					if(nImg >= 10) nn = IJ.pad(nn,2); // adjust the series number
					selectWindow(workFold[d] + "Seq"+seq+".nd2 - Seq"+seq+".nd2 (series "+nn+")");
					rename(saveTitle + seq + "_cs" + (d + 1) + "_" + IJ.pad(n,3));
					tempTitle = getTitle(); // for calling after aligment

					// register stack
					getDimensions(width, height, channels, slices, frames);
					if(channels > 1){
						run("Split Channels");
						for(c=1;c<4;c++){
							selectWindow("C"+c+"-"+tempTitle);
							run("StackReg", "transformation=Translation");
						}
						run("Merge Channels...", "c1=C1-"+tempTitle+" c2=C2-"+tempTitle+" c3=C3-"+tempTitle+" create");
						run("Z Project...", "projection=[Max Intensity]");
						rename("MAX_" + tempTitle);
						selectWindow(tempTitle);
						nTemp = 2;
					} else {
						if(slices > 1){
							run("StackReg", "transformation=Translation");
							run("Z Project...", "projection=[Max Intensity]");
							rename("MAX_" + tempTitle);
							selectWindow(tempTitle);
							nTemp = 2;
						} else {
							nTemp = 1;
						}
					}
	
					// save file(s) checking if there is a MAX projection
					run("Save", "save=" + savePath + tempTitle + ".tif");
					close();
					if(nTemp == 2){
						selectWindow("MAX_" + tempTitle);
						run("Save", "save=" + savePath + "MAX_" + tempTitle + ".tif");
						close();
					}
					n ++;
				}
			}
		}
	}
	showStatus("Converting nd2 sequences: DONE!");
}

