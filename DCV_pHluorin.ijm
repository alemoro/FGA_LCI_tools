// DCV-pHluorin Analyzer

/*
This toolset implement different functionality for the analysis of neuropeptide labelled with pHluorin. it was developed and tested using NPY-pHluorin.
The idea of this toolset is to provide an semi-automatic analysis of dense-core vesicles fusion events in primary neuronal culture.
The toolset consists of: ROI placement (automatic; exporting as maximum projection for SynD);
						 Manual ROI placement;
						 ROI interaction (save, measure, navigate);
						 ROI frame reader.
The toolset will provide different options to match the end user.

Start developing 2015.12.01

Modify           
	2016.12.08 - Add new function: automatic detection
	2016.12.09 - Test automatic detection; add filter for detection; modify the "Option" file
	2016.12.13 - Bug correction and plugin checks
	2017.01.08 - Update detection function
	2017.01.17 - Cleanup code and extract function
	2017.01.18 - Debug and implement new parameters
	2017.01.19 - Add option for detect ROI in a selection
	2017.05.01 - Add option for detect ROI every N frames
	2017.07.11 - Add background correction
	2017.07.13 - Several bugs fixed and increased speed
	2017.07.14 - version 1.0 released
*/

var majVer = 1;
var minVer = 0;
var about = "Developed by Alessandro Moro<br>"
			+ "<i>Department of Functional Genomics</i> (FGA)<br>"
			+ "<i>Centre of neuroscience and cognitive research</i> (CNCR)<br>"
			+ "<i>Vrij Universiteit</i> (VU) Amsterdam.<br>"
			+ "<i>email: a.moro@vu.nl</i><br><br><br>";

			
// Initialize the variables
var fOption;
var wd = getDirectory("Image");
var	InvertedLUT;
var	StartZoom;
var AlignStack;
var	Autoadd;
var	ROI_size;
var	ROI_shape;
var	saveas;
var	folder;
var	Autosave;
var	MovetoZoom;
var sensitivity = newArray("Very dim particles (SNR=3)", "Dim particles (SNR=4)", "Bright particles (SNR=5)", "Brighter particles (SNR=10)", "Pretty bright particles (SNR=20)", "Very bright particles (SNR=30)");
var	sizes = newArray("2", "3", "4", "5", "6", "7");
var nh4Start;
var bBaseline;
var bRolling;
var BGframes;
var detSizes = newArray(6);
var snr;
var sigma;
var detSigma;
var cleSigma;
var roiOver;
var gapFrames;
var bRecursively;
var nIteration;
var bInclude;
var detectEvery;
var remRegions = false;

////////////////////////////////////////
/////////PRELIMINARY FUNCTIONS/////////
///////////////////////////////////////

// even before starting check if it's the first time it's run
bFirst = call("ij.Prefs.get", "detectionPar.bFirst", true);
if(bFirst == 1){
	setDefaultParameters(false);
	setDefaultOptions(true);
	call("ij.Prefs.set", "detectionPar.bFirst", false);
}
loadOptions();

// if there is one image open check the there is in the correct format (need to work with imageID!!)
if(nImages > 0){
	title = getTitle();
	if (!endsWith(title, ".tif")){
		rename(title + ".tif");
	}
}

// get the display options from the ij.Prefs
function loadOptions(){
	// get the options from the ij.Prefs
	InvertedLUT = call("ij.Prefs.get", "detectionOpt.InvertedLUT", true);
	StartZoom = call("ij.Prefs.get", "detectionOpt.StartZoom", true);
	AlignStack = call("ij.Prefs.get", "detectionOpt.AlignStack", true);
	Autoadd = call("ij.Prefs.get", "detectionOpt.Autoadd", true);
	ROI_size = call("ij.Prefs.get", "detectionOpt.ROI_size", true);
	ROI_shape = call("ij.Prefs.get", "detectionOpt.ROI_shape", true);
	saveas = call("ij.Prefs.get", "detectionOpt.saveas", true);
  	folder = call("ij.Prefs.get", "detectionOpt.folder", true);
  	Autosave = call("ij.Prefs.get", "detectionOpt.Autosave", true);
  	MovetoZoom = call("ij.Prefs.get", "detectionOpt.MovetoZoom", true);
}

// set the default display option
function setDefaultOptions(arg){
	//  this function uses the ij.Prefs file to store the options; if it is the first time that the program is called it will create a default value, there is no need for a reset as those are marely personal taste of the end user
	call("ij.Prefs.set", "detectionOpt.InvertedLUT", false);
	call("ij.Prefs.set", "detectionOpt.StartZoom", false);
	call("ij.Prefs.set", "detectionOpt.AlignStack", false);
	call("ij.Prefs.set", "detectionOpt.Autoadd", true);
	call("ij.Prefs.set", "detectionOpt.ROI_size", 2);
	call("ij.Prefs.set", "detectionOpt.ROI_shape", "Rectangle");
	call("ij.Prefs.set", "detectionOpt.saveas", "fullname");
	call("ij.Prefs.set", "detectionOpt.folder", "Current Folder");
	call("ij.Prefs.set", "detectionOpt.Autosave", true);
	call("ij.Prefs.set", "detectionOpt.MovetoZoom", false);
	if(arg)
		SetOptions();
}

// dialog for the display options
function SetOptions(){
	// get the options
	loadOptions();
	// Real function for the options dialog
  	Dialog.create("pHluorin Analysis Option");
  	Dialog.addCheckbox("Inverted LUT", InvertedLUT);
	Dialog.addCheckbox("Zoom in at start", StartZoom);
	Dialog.addCheckbox("Align stack", AlignStack);
	Dialog.addMessage("Place ROI Options:");
	Dialog.addCheckbox("Auto add ROI", Autoadd);
	Dialog.addNumber("ROI size:", ROI_size);
	Dialog.addChoice("ROIs shape:", newArray("Rectangle", "Oval"), ROI_shape);
	Dialog.addMessage("Save Options:");
	Dialog.addChoice("Save ROIs as:", newArray("cs and cell ID", "fullname"), saveas);
	Dialog.addChoice("Save ROI in:" ,newArray("Current Folder", "Specific Folder", "New Folder"), folder);
	Dialog.addCheckbox("Autosave after measuring", Autosave);
	Dialog.addMessage("Move to ROI Options:");
	Dialog.addCheckbox("Full zoom to ROI", MovetoZoom);
	Dialog.show();
	InvertedLUT  = Dialog.getCheckbox();
	StartZoom    = Dialog.getCheckbox();
	AlignStack   = Dialog.getCheckbox();
	Autoadd      = Dialog.getCheckbox();
	ROI_size     = Dialog.getNumber();
	ROI_shape    = Dialog.getChoice();
	saveas       = Dialog.getChoice();
  	folder       = Dialog.getChoice();
  	Autosave     = Dialog.getCheckbox();
  	MovetoZoom   = Dialog.getCheckbox();
  	// save the options in the ij.Prefs
	call("ij.Prefs.set", "detectionOpt.InvertedLUT", InvertedLUT);
	call("ij.Prefs.set", "detectionOpt.StartZoom", StartZoom);
	call("ij.Prefs.set", "detectionOpt.AlignStack", AlignStack);
	call("ij.Prefs.set", "detectionOpt.Autoadd", Autoadd);
	call("ij.Prefs.set", "detectionOpt.ROI_size", ROI_size);
	call("ij.Prefs.set", "detectionOpt.ROI_shape", ROI_shape);
	call("ij.Prefs.set", "detectionOpt.saveas", saveas);
	call("ij.Prefs.set", "detectionOpt.folder", folder);
	call("ij.Prefs.set", "detectionOpt.Autosave", Autosave);
	call("ij.Prefs.set", "detectionOpt.MovetoZoom", MovetoZoom);
}

// set the default detection parameters
function setDefaultParameters(arg){
	// this function uses the ij.Prefs file to store the parameter; if it is the first time that the program is called it will create a default value, this particular function will be called also if the paramer as set as "Reset"
	call("ij.Prefs.set", "detectionPar.nh4Start", 161);
	call("ij.Prefs.set", "detectionPar.bBaseline", false);
	call("ij.Prefs.set", "detectionPar.bRolling", true);
	call("ij.Prefs.set", "detectionPar.bgFrames", 30);
	ds = newArray(false, false, true, false, false, false);
	for(d=0;d<6;d++)
		call("ij.Prefs.set", "detectionPar.detSizes"+d, ds[d]);
	call("ij.Prefs.set", "detectionPar.snr", "Very dim particles (SNR=3)");
	call("ij.Prefs.set", "detectionPar.sigma", 0.7);
	call("ij.Prefs.set", "detectionPar.detSigma", 3);
	call("ij.Prefs.set", "detectionPar.cleSigma", 3);
	call("ij.Prefs.set", "detectionPar.roiOver", 4);
	call("ij.Prefs.set", "detectionPar.gapFrames", 1);
	call("ij.Prefs.set", "detectionPar.bRecursively", false);
	call("ij.Prefs.set", "detectionPar.nIteration", 1);
	call("ij.Prefs.set", "detectionPar.bInclude", false);
	call("ij.Prefs.set", "detectionPar.detectEvery", 30);
	if(arg) detectionParameters();
}

// dialog for the detection paramer
function detectionParameters(){
	// get the parameters fromt the ij.Prefs file
	nh4Start = call("ij.Prefs.get", "detectionPar.nh4Start", true);
	bBaseline = call("ij.Prefs.get", "detectionPar.bBaseline", true);
	bRolling = call("ij.Prefs.get", "detectionPar.bRolling", true);
	BGframes = call("ij.Prefs.get", "detectionPar.bgFrames", true);
	for(d=0;d<6;d++)
		detSizes[d] = call("ij.Prefs.get", "detectionPar.detSizes"+d, true);
	snr = call("ij.Prefs.get", "detectionPar.snr", true);
	sigma = call("ij.Prefs.get", "detectionPar.sigma", true);
	detSigma = call("ij.Prefs.get", "detectionPar.detSigma", true);
	cleSigma = call("ij.Prefs.get", "detectionPar.cleSigma", true);
	roiOver = call("ij.Prefs.get", "detectionPar.roiOver", true);
	gapFrames = call("ij.Prefs.get", "detectionPar.gapFrames", true);
	bRecursively = call("ij.Prefs.get", "detectionPar.bRecursively", true);
	nIteration = call("ij.Prefs.get", "detectionPar.nIteration", true);
	bInclude = call("ij.Prefs.get", "detectionPar.bInclude", true);
	detectEvery = call("ij.Prefs.get", "detectionPar.detectEvery", true);
	
	// create a dialog to add the parameters: basic
	Dialog.create("Detection options")'
	Dialog.addNumber("Start of NH4 (frame)", nh4Start);
	Dialog.addSlider("Num of gap frames", 1, 5, gapFrames);
	Dialog.addCheckbox("Baseline subtraction?", bBaseline);
	Dialog.addCheckbox("Rolling STD?", bRolling);
	Dialog.addNumber("Baseline frames", BGframes);
	Dialog.addMessage("Estimate size of particles (in px)");
	Dialog.addCheckboxGroup(2,3,sizes,detSizes);
	Dialog.addChoice("Signal to noise", sensitivity, snr);
	Dialog.addSlider("Gaussian blur radius", 0.3, 1.5, sigma);
	Dialog.addNumber("Detection sigma (n*Std)", detSigma);
	Dialog.addNumber("Cleaning sigma (n*Std)", cleSigma);
	Dialog.addCheckbox("Remove regions", false);
	Dialog.addCheckbox("Advance Options", false);
	Dialog.show();
	nh4Start = Dialog.getNumber();
	gapFrames = Dialog.getNumber();
	bBaseline = Dialog.getCheckbox();
	bRolling = Dialog.getCheckbox();
	BGframes = Dialog.getNumber();
	detSizes = newArray(6);
	for(i=0; i<6; i++)
		detSizes[i] = Dialog.getCheckbox();
	snr = Dialog.getChoice();
	sigma = Dialog.getNumber();
	detSigma = Dialog.getNumber();
	cleSigma = Dialog.getNumber();
	remRegions = Dialog.getCheckbox();
	advOption = Dialog.getCheckbox();

	// set the new parameters to the ij.Prefs file
	call("ij.Prefs.set", "detectionPar.nh4Start", nh4Start);
	call("ij.Prefs.set", "detectionPar.gapFrames", gapFrames);
	call("ij.Prefs.set", "detectionPar.bBaseline", bBaseline);
	call("ij.Prefs.set", "detectionPar.bRolling", bRolling);
	call("ij.Prefs.set", "detectionPar.bgFrames", BGframes);
	for(d=0;d<6;d++)
		call("ij.Prefs.set", "detectionPar.detSizes"+d, detSizes[d]);
	call("ij.Prefs.set", "detectionPar.snr", snr);
	call("ij.Prefs.set", "detectionPar.sigma", sigma);
	call("ij.Prefs.set", "detectionPar.detSigma", detSigma);
	call("ij.Prefs.set", "detectionPar.cleSigma", cleSigma);

	// check if the advance options are checked
	if(advOption){
		// check the possible frame divisors
		usedFrames = nh4Start - (1 + gapFrames);
		nDiv = "Possible frames are: 1";
		for(ii = 2; ii <= usedFrames; ii++){
			if(usedFrames % ii == 0){
				nDiv = nDiv + ", " + ii;
			}
		}
		Dialog.create("Advance detenction option");
		Dialog.addNumber("ROI overlap", roiOver)
		Dialog.addCheckbox("Run recursively (experimental)", bRecursively);
		Dialog.addSlider("Number of iteration", 1, 5, nIteration);
		Dialog.addCheckbox("Detect at selection", bInclude);
		Dialog.addCheckbox("Reset parameters", false);
		Dialog.addNumber("Detect every N frames", detectEvery);
		Dialog.addMessage(nDiv);
		Dialog.show();
		roiOver = Dialog.getNumber();
		bRecursively = Dialog.getCheckbox();
		nIteration = Dialog.getNumber();
		bInclude = Dialog.getCheckbox();
		bReset = Dialog.getCheckbox();
		detectEvery = Dialog.getNumber();
		if(usedFrames % detectEvery != 0){
			detectEvery = usedFrames;
		}
		if(bReset){
			setDefaultParameters(true);
		}else{
			call("ij.Prefs.set", "detectionPar.roiOver", roiOver);
			call("ij.Prefs.set", "detectionPar.bRecursively", bRecursively);
			call("ij.Prefs.set", "detectionPar.nIteration", nIteration);
			call("ij.Prefs.set", "detectionPar.bInclude", bInclude);
			call("ij.Prefs.set", "detectionPar.detectEvery", detectEvery);
		}
	}
}


/////////////////////////////////////
/////////CREATE THE TOOLSET/////////
////////////////////////////////////

// leave one empty slot
macro "Unused Tool -1-" {} 

// Start Analysis -> fusion detection; export to SynD; Options
var sCmds1 = newMenu("Start Analysis Menu Tool", newArray("Fusion detection", "Export to SynD", "-", "Options"));
macro "Start Analysis Menu Tool - C555T1d13 T9d13 R01fbR2397 Cd00T1d13 T9d13 D00D01D02D03D0dD0eD0fD10D11D12D13D14D1cD1dD1eD1fD20D21D24D25D2bD2cD2eD2fD30D31D35D36D3aD3bD3eD3fD40D41D46D47D49D4aD4eD4fD50D51D57D58D59D5eD5fD60D61D68D6eD6fD70D71D7eD7fD80D81D82D83D8cD8dD8eD8fD90D91D92D93D9cD9dD9eD9f"{
	cmd1 = getArgument();
	if (cmd1 == "Options"){
		loadOptions();
		SetOptions();
	}
	else if (cmd1 == "Fusion detection"){
		title = getTitle();
		if (!endsWith(title, ".tif")){
			rename(title + ".tif");
		}
		loadOptions();
		StartAnalysis(title);
	}
	else if (cmd1 == "Export to SynD"){
		loadOptions();
		exportToSynD();
	}
}

// Place ROIs -> automatically with defined size, shape and add them to ROI manager, double click for specific options
macro "Place ROIs Tool -C5d5T1d13 T9d13 R0977 Cdd0T1d13 T9d13 D1dD2aD2bD2cD37D38D39D3aD3bD3eD43D44D45D46D47D48D49D4aD4dD4eD53D54D55D56D57D58D59D5cD5dD63D64D65D66D67D68D6bD6cD6dD73D74D75D76D77D7aD7bD7cD7dD84D85D86D87D89D8aD8bD8cD92D93D95D96D97D98D99D9aD9bD9cDa1Da2Da3Da4Da6Da7Da8Da9DaaDabDacDb2Db3Db4Db5Db7Db8Db9DbaDbbDbcDc3Dc4Dc5Dc6Dc8Dc9DcaDcbDccDd4Dd5Dd6De5De6"{
	loadOptions();
	PlaceROIs();
}

macro "Place ROIs Tool Options ..."{
	loadOptions();
	// small dialog only to change the ROI shape and size
	if(matches(ROI_shape,"Rectagle")){
		roiShape = 1;
	}else{
		roiShape = 2;
	}
	shapes = newArray("Rectangle", "Oval");
	Dialog.create("ROI shape and size ");
	Dialog.addRadioButtonGroup("Shape", shapes, 1, 2, roiShape);
	Dialog.addSlider("Size", 1, 10, ROI_size);
	Dialog.show();
	NewShape = Dialog.getRadioButton();
	NewSize  = Dialog.getNumber();
	ROI_shape = NewShape;
	ROI_size  = NewSize;
	// save the new shape and size
	call("ij.Prefs.set", "detectionOpt.ROI_size", ROI_size);
	call("ij.Prefs.set", "detectionOpt.ROI_shape", ROI_shape);
}


// Save ROIs -> with the proper name, cs and cell ID or full name, in the proper folder
var sCmds2 = newMenu("ROIs Interacion Menu Tool", newArray("Save ROI", "Measure ROIs", "Move through ROIs", "-", "Options"));
macro "ROIs Interacion Menu Tool - C5d5T1d13 T9d13 R9077  C555T1d13 T9d13 D2aD3aD3bD4aD4bD4cD50D51D52D53D54D55D56D57D58D59D5aD5bD5cD5dD60D61D62D63D64D65D66D67D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D77D78D79D7aD7bD7cD7dD7eD7fD80D81D82D83D84D85D86D87D88D89D8aD8bD8cD8dD8eD90D91D92D93D94D95D96D97D98D99D9aD9bD9cD9dDaaDabDacDbaDbbDca"{
	cmd2 = getArgument();
	loadOptions();
	if (cmd2 == "Save ROI")
		SaveROIs();
	else if (cmd2 == "Measure ROIs")
		MeasureEvents();
	else if (cmd2 == "Move through ROIs")
		MovetoROI();
	else if (cmd2 == "Options")
		SetOptions();
}

// ROIs frames -> read all the RoiSet.zip file in the specified folder reporting the name and frame number
var sCmds3 = newMenu("ROIs Frames Reader Menu Tool", newArray("From ROI Manager", "From File", "From Folder"));
macro "ROIs Frames Reader Menu Tool - C5d5T1d13 T9d13 R9077R9977 C555T1d13 T9d13 L00f0L03f3L06f6L09f9L0cfcL0fbf"{
	cmd3 = getArgument();
	loadOptions();
	if (cmd3 == "From ROI Manager")
		what = "manager";
	else if (cmd3 == "From File")
		what = "file";
	else if (cmd3 == "From Folder")
		what = "folder";
	ROIreader(what);
}

// Documentation!!!
macro "Help... Action Tool - C000D84Cb9fD25De7CaaaD14D2dDa0DafDecDfaCedfD49D4aD4bD4cD58D68D9bDb9DbaDbbDbcC889D2cDebCddfD52CcccD0bD22CeeeD00D03D0cD0fD10D1fD20D2fD30D40Dc0Dd0DdfDe0DefDf0Df1Df2Df3DfcDfeDffC666D07D70CdcfD34D35Dc4CbacD86D91CfefD6bD6dD7cD8cD8dD8eD9cD9dDadC97aDd3De5CedfD99CeeeD01D02D04D0dD0eD11D12D1eD21D3fDcfDd1De1De2DeeDf4DfdCfefD7dC545D94Da5CdbeDa4Da7CbabD05D50DaeCfefD7eC98aD32Da1CecfD39D3aD3bD46D48D57D67Da8Db6Db8Dc9DcaDcbDccCdcdD81C878D1bD60D65CdcfD29D36D38D47D77Db7Dc8Dd9DdaCcbcD7aDbfDc1De3C98bD16D24D75DeaCedfD56D66D73D76D83D93Da3C212D7bD88D96D97CcaeD26D3cDdbCaaaD3eD5fCfdfD59C889D15D1aD78Dc2CdcfD45Db4Db5Dc6CdddD13D31D4fDdeDedDfbC777D09D7fD85D90Df7CeceDbdCbadD18D55Db2De9Ca9aD5eDcdDceDdcC656D08D64D80D87D8bCdbfD28D2aD37Dc7Dd8CbbbD1cD42Dd2Df5CfdfD5aD5bD5cD5dD69D6aD6cD9aDa9DabDacC999D0aD41DddDf6CdddD1dD2eD9eDb0C888D06D4eD6fD9fDf9CcbdD54D71D98Dc3Ca9dD17D19Dd4De6C000D74D79D95CcafDd5Dd6De8CedfD62D72D92C889D51Db1DbeCedfD53D63Da2CdcdD6eC777D8fDf8CdcfD43D44Db3Dc5CbadD2bD33C99aD23De4C545D89Da6CcbfD27Dd7CbabD61CedfD82DaaC98aD3dCdceD4dD8a"{
	message = "<html>"
	 + "<h2>Version " + majVer + "." + minVer + "</h2><br>"
	 + about + "<br>"
	 + "The documentation could be found "
	 + "<a href=\"https://github.com/alemoro/FGA_LCI_tools/blob/master/DCV_pHluorin%20documentation.pdf\">here.</a><br>"
	 + "<a href=\"http://www.johanneshjorth.se/SynD/SynD.html\">SynD</a><br>"
	 + "<a href=\"https://dreamdealer.net/redmine/projects\">Fusion Analysis 2</a><br>"
	 + "<a href=\"http://bigwww.epfl.ch/thevenaz/stackreg/\">StackReg</a><br>"
	 + "<a href=\"http://imagej.net/MorphoLibJ\">MorphoLibJ</a><br>"
	 + "<a href=\"https://imagej.net/Spots_colocalization_(ComDet)\">ComDet</a>.<br>"
	Dialog.create("Help");
	Dialog.addMessage("Version " + majVer + "." + minVer + ", \nclick \"Help\" for more");
	Dialog.addHelp(message);
	Dialog.show;
	//showMessage("Not very usefull", message);
}


///////////////////////////////////
/////////GENERAL FUNCTIONS/////////
///////////////////////////////////

// Start Analysis Menu functions
function StartAnalysis(title){
	// first check if the timelapse need to be align
	if (AlignStack)
		run("StackReg", "transformation=[Rigid Body]");
	// ok now detect some fusion events
	detectParticles();
	// check if the LUT need to be inverted and zoomed in
	if (InvertedLUT)
		run("Invert", "stack");
	if (StartZoom == 1){
		run("In [+]");
		run("In [+]");
	}
}

// ROI Manager cleaning from overlapping RoiSet
function cleanupRoiManager(roiOver){
	// get one ROI pixel location, get all the subsequent ROI and check if there are pixel overlapping the two, if there are more pixel overlapping than what the end user wants, delete the second ROI
	print("Cleaning ROI Manager from overlaps");
	nRoi = roiManager("count");
	r = 0;
	while(r<nRoi){
		showProgress(-(r+1),nRoi);
		showStatus("Cleaning Roi Manager " +r+"/"+nRoi);
		roiManager("Select", r);
		r1 = 0;
		Roi.getBounds(x0, y0, width0, height0);
		while(r1<nRoi){
			if(r==r1){r1++;}
			if(r1 < nRoi){
				roiManager("Select", r1);
				bROI = 0;
				for(x = x0; x < x0+width0; x++){
					for(y = y0; y <y0+height0; y++){
						bROI = bROI + Roi.contains(x,y);
					}
				}
				if(bROI > roiOver){
					roiManager("Delete");
					nRoi = nRoi - 1;
					r1 = r1;
				} else {
					r1++;
				}
			}
		}
		r++;
	}
	return "ROI Manager cleaned";
}

// Create a 2x2 Roi from a 3x3 Roi
function refineRoi(bAll){
	nRoi = roiManager("Count");
	meanPeak = newArray(4);
	meanBase = newArray(4);
	mean = newArray(4);
	max= newArray(4);
	for(r=0;r<nRoi;r++){
		showProgress(-(r+1),nRoi);
		showStatus("Adjust ROI Placement " +r+"/"+nRoi);
		if(bAll){
			// can be call only for one Roi
			roiManager("Select", r);
		}
		
		// get a baseline level
		Roi.getBounds(x0, y0, w0, h0);
		run("Previous Slice [<]");
		b = 0;
		for(x=0;x<2;x++){
			for(y=0;y<2;y++){
				makeRectangle(x0+x,y0+y,2,2);
				getStatistics(a, meanBase[b], m, M, std, h);
				b++;
			}
		}
		
		// get the peak level: need to add a second frame to have a more accurate measure
		run("Next Slice [>]");
		p = 0;
		for(x=0;x<2;x++){
			for(y=0;y<2;y++){
				makeRectangle(x0+x,y0+y,2,2);
				getStatistics(a, meanPeak[p], m, M, std, h);
				p++;
			}
		}
		
		// check the sub Roi with the highest fusion peak
		for(m=0;m<4;m++){
			mean[m] = meanPeak[m] / meanBase[m];
			max[m] = meanPeak[m] / meanBase[m];
		}
		Array.sort(max);
		if(max[3] == mean[0]){
			makeRectangle(x0, y0, 2, 2);	
		} if(max[3] == mean[1]){
			makeRectangle(x0, y0+1, 2, 2);
		} if(max[3] == mean[2]){
			makeRectangle(x0+1, y0, 2, 2);
		} if(max[3] == mean[3]){
			makeRectangle(x0+1, y0+1, 2, 2);
		}
		roiManager("Update");
		if(!bAll){
			// only one Roi to adjust
			r = nRoi;
		}
	}
}

// Option for exporting to SynD: marker, frames, batch processing
function exportToSynD(){
	Dialog.create("Export to SynD");
	Dialog.addChoice("Marker", newArray("pHluorin", "mCherry"), "pHluorin");
	Dialog.addNumber("Start frame", 161);
	Dialog.addNumber("End frame", 166);
	Dialog.addChoice("Projection", newArray("Max Intensity", "Average Intensity", "Standard Deviation"));
	Dialog.addCheckbox("Process folder", 1);
	Dialog.show;
	marker = Dialog.getChoice();
	startF = Dialog.getNumber();
	endF = Dialog.getNumber();
	Zproj = Dialog.getChoice();
	bFolder = Dialog.getCheckbox();

	if (bFolder == 1){
		// do it in an entire set of files automatically
		workDir = getDirectory("Select movies folder");
		saveDir = getDirectory("Select saving folder");
		fileList = getFileList(workDir);
		nFile = fileList.length;
		setBatchMode(true);
		for(f = 0; f < nFile; f++){
			showProgress(f+1,nFile);
			showStatus("Exporting to SynD " +f+1+"/"+nFile);
			file = fileList[f];
			if ((endsWith(file, ".tif")) || (endsWith(file, ".TIF"))){
				open(workDir + file);
				title = getTitle();
				getDimensions(width, height, channels, slices, frames);
				if ((slices < 2) && (frames < 2)){
					close(title);
				}
				saveForSynD(title, marker, startF, endF, Zproj);
				while (nImages > 0){
					close();
				}
			}
		}
		setBatchMode(false);
	} else {
		wd = getDirectory("Image");
		title = getTitle();
		if (!endsWith(title, ".tif")){
			rename(title + ".tif");
		}
		title = getTitle();
		selectWindow(title);
		sTitle = substring(title, 0, lengthOf(title) - 4);
		saveForSynD(title, marker, startF, endF, Zproj);
	}
}

// Function to exporting an image to SynD to calculate the total pool of vesicles
function saveForSynD(title, marker, startF, endF, Zproj){
	sTitle = substring(title, 0, lengthOf(title) - 4);
	if (marker == "pHluorin"){
		// get an overview of the ammonia response and delete the first frame to have a subtraction of the initial baseline
		run("Duplicate...", " ");
		rename("firstFrame");
		selectWindow(title);
		run("Duplicate...", "duplicate range=" + startF + "-" + endF);
		run("Z Project...", "projection=[" + Zproj + "]");
		rename("Average");
		close(sTitle + "-2.tif");
		imageCalculator("Subtract create", "Average","firstFrame");
			rename("Ammonium");
		close("Average");
		close("firstFrame");
		selectWindow("Ammonium");
	} else {
		// in the case of a not pH sensitive fluorophore use an average of the first frames
		run("Duplicate...", "duplicate range=" + startF + "-" + endF);
		run("Z Project...", "projection=[" + Zproj + "]");
		rename("Average");
		close(sTitle + "-1.tif");
		selectWindow("Average");
	}
	saveAs("Tiff", saveDir + "\\" + sTitle + "_pool.tif");
}

/////////////////////////////////////
/////////DETECTION FUNCTIONS/////////
/////////////////////////////////////

// Main function for the particle detection, thus far uses the ComDet plugin as main detection algorithm
function detectParticles(){
	// first check if the correct plugin is installed
	pluginDir = getDirectory("plugins");
	plugins = getFileList(pluginDir);
	for(p=0;p<plugins.length;p++){
		tempP = plugins[p];
		bDetection = indexOf(tempP, "ComDet_") >= 0;
		if(bDetection)	p = plugins.length;
	}
	// if not warn the user and guide him to download the plugin
	if(!bDetection){
		message = "<html>"
		+"<h2>ComDet missing</h2>"
		+"Please install the ComDet plugin before continue.<br>"
		+"<a href=https://github.com/ekatrukha/ComDet/wiki>Take me to the plugin.</a>";
		Dialog.create("Plugin mising");
		Dialog.addMessage("Press help...");
		Dialog.addHelp(message);
		Dialog.show;
	} else {
		// first set the parameters
		orTitle = getTitle(); // need to think in imageID
		detectionParameters();
		// log them for second uses and record
		print("_________________________________________________________\n"
			+"Starting Project Heaven with parameters:\n"
			+"Baseline subtraction: " + bBaseline + "\n"
			+"Rolling standard deviation detection: " + bRolling + "\n"
			+"Signal to noise detection: " + snr + "\n"
			+"Gaussian blur sigma (for smoothing): " + sigma + "\n"
			+"Detection sigma (mean + sigma * std): " + detSigma + "\n"
			+"Cleaning sigma (mean + sigma * std): " + cleSigma + "\n"
			+"Touching ROIs (number of pixel): " + roiOver + "\n"
			+"Gap between frames: " + gapFrames + "\n"
			+"Run recursively: " + bRecursively + "\n"
			+"Number of Iteration: " + nIteration + "\n"
			+"Analysis of image: " + orTitle + "\n"
			+"_________________________________________________________");
		// get the time (for fun)
		time0 = getTime();
		// add for iterations
		arg = false;
		for(iter=0;iter<nIteration;iter++){
			print("Iteration #: " + iter + 1);
			// Start getting the MAX_diff image after a stack subtraction
			selectWindow(orTitle);
			if(!bInclude){
				// remove any ROI from the image to avoid mistake running
				run("Select None");
			} else {
				// actually, you need to keep what the user selected (aka a neurite mask)
				if(iter == 0){
					rename("START_"+orTitle);
					run("Select None");
					run("Duplicate...", "duplicate");
					rename(orTitle);
					run("Restore Selection");
					run("Clear Outside", "stack");
				}
			}
			// otherwhise if there not a proper mask the user can delete background regions
			if(remRegions && iter == 0){
				setTool("polygon");
				rename("START_"+orTitle);
				run("Select None");
				run("Duplicate...", "duplicate");
				rename(orTitle);
				while(!isKeyDown("shift")){
					// cheap non modal dialog in ijm
					waitForUser("Trace region to exclude.\nTo add a new line click \"OK\".\nTo continue click shift+\"OK\"");
					if(isKeyDown("shift")){
						setKeyDown("none");
						setForegroundColor(255, 0, 255); // don't set it to black to not have 0 value pixel in the calculation
						run("Fill", "stack");
						setKeyDown("shift");
					}else{
						setForegroundColor(255, 0, 255);
						run("Fill", "stack");
					}
				}
			}
			run("Select None");
			run("Duplicate...", "duplicate range=1-" + nh4Start -1);
			rename("tempDiff");
			
			// now the image is set, check for iteration: detect one, remove detected particles, run again
			if(iter > 0){
				arg = true;
				for(r=0;r<roiManager("count");r++){
					roiManager("Select", r); 
					run("Fill", "stack");// try to hide the previous detected roi
				}
			}
			
			// Actual start of the detection: stack subtraction with a 3D gaussian blur to remove some of the scatter noise
			setPasteMode("Subtract");
			selectWindow("tempDiff");
			run("Gaussian Blur 3D...", "x=" + sigma +" y=" + sigma +" z=" + sigma);
			run("Set Slice...", "slice="+nSlices);
			run("Select All");
			
			// gap frames are useful to detect better event that need more than one frame to arrive at the maximum, events that are only one frame will be detect anyhow
			for(i=nSlices; i>gapFrames; i--) {
				setSlice(i-gapFrames);
		    	run("Copy");
		    	setSlice(i);
				run("Paste");
			}
			run("Select None");
			selectWindow("tempDiff");
			run("Duplicate...", "duplicate range=" + (1+gapFrames) + "-" + nSlices);
			rename("Diff_" + orTitle);
			selectWindow("tempDiff");
			close();
			selectWindow("Diff_" + orTitle);
			setSlice(1);
			run("Min...", "value=1 stack"); // to avoid 0 in pixel values
			
			// check if there is the need to do a baseline correction
			if(bBaseline){
				
				// get a baseline stack
				run("Duplicate...", "duplicate range=1-" + BGframes);
				rename("BaseStk");
				tempBGmean = newArray(BGframes);
				tempBGstd = newArray(BGframes);
				s = 0;
				while(s< BGframes){
					getStatistics(bgA, tempBGmean[s], BGmin, BGmax, tempBGstd[s], BGhistogram);
					s++;
					run("Next Slice [>]");
				}
				Array.getStatistics(tempBGmean, BGmin, BGmax, BGmean);
				Array.getStatistics(tempBGstd, BGmin, BGmax, BGstd);
				
				// remove the baseline noise (as mean + n * std)
				subtract = BGmean + detSigma * BGstd;
				selectWindow("BaseStk");
				close();
				selectWindow("Diff_" + orTitle);
				run("Subtract...", "value=" + subtract + " stack");
			}
			
			// Detect every N frames, so split the image to collect "all" the ROIs
			run("Grouped Z Project...", "projection=[Max Intensity] group=" + detectEvery);
			rename("tempMax");
			
			/*
			I first need to create the proper loop to use the morphological filter to clean even more from scatter noise
			run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=2");
			selectWindow("tempMax");
			close();
			selectWindow("tempMax-White Top Hat");
			rename("tempMax");
			*/
			
			// then particles detection: ask for sensitivity (the minumum, from there brighter particles will be already detected) and predicted size
			for(d=0; d<6; d++){
				apx = detSizes[d] * sizes[d];
				if(apx > 0){
					run("Detect Particles", "  ch1a="+apx+" ch1s=["+snr+"]"); // ComDet plugin in action
					
					// get the center point of the particles and create a 3x3 ROI in the Roi Manager
					for(r=0; r < nResults; r++){
						xLoc = round(getResult("X_(px)", r) - 1);
						yLoc = round(getResult("Y_(px)", r) - 1);
						makeRectangle(xLoc, yLoc, 3, 3);
						roiManager("Add");
					}
					run("Select None");
					run("Remove Overlay");
				}
			}
			
			// clean some outdate images
			selectWindow("Results");
			run("Close");
			selectWindow("Summary");
			run("Close");
			selectWindow("Diff_" + orTitle);
			close();
			selectWindow("tempMax");
			close();
			
			// enter in batch mode for speed
			selectWindow(orTitle);
			setBatchMode("hide");
			setBatchMode(true);
			
			// clean the Roi Manager from overlaps
			aa = cleanupRoiManager(roiOver);
			run("Remove Overlay");
			print(aa);
			print("Detect " + roiManager("Count") + " ROI");
			run("Remove Overlay");
						
			// Create a matrix (image) where every row is one vesicle and every column one frame
			selectWindow(orTitle);
			roiManager("Deselect");
			showStatus("Measuring ROIs (this might take a while)");
			roiManager("Multi Measure");
			nRoi = roiManager("Count");
			newImage("allVes", "32-bit black", nh4Start, nRoi, 1);
			for(cc=1; cc<nRoi; cc++){
				for(rr=1; rr<=nh4Start; rr++){
					setPixel(rr-1,cc-1,getResult("Mean"+cc,rr-1));
				}
			}
			selectWindow("Results");
			run("Close");
			
			// third step in the workflow, detect the frame where the event happen
			//setBatchMode("exit and display");
			r = 0;
			l = 0;
			while(l<nRoi){
				showProgress(r+1,nRoi);
				showStatus("Detecting Frame " + l+1 +"/" + nRoi);
				selectWindow(orTitle);
				roiManager("Select",r);
				selectWindow("allVes");
				makeRectangle(0, l, nh4Start, 1);
				detFrame = detectFrame();
				selectWindow(orTitle);
				roiManager("Select",r);
				if(detFrame > 0){
					//we have a positive candidate
					setSlice(detFrame);
					roiManager("Update");
					l++;
					r++;
				} else {
					// just a bright spot
					roiManager("Delete");
					l++;
				}
			}
			selectWindow("allVes");
			close();
			run("Select None");
			setBatchMode("exit and display");
			run("Remove Overlay");
		}
		
		selectWindow(orTitle);
		//setBatchMode("hide");
		
		// check the desired size of the ROI and in case change it
		if(ROI_size < 3){
			print("Refine ROI area");
			refineRoi(true);
		}
		
		// log the outcome
		print("Succesfully placed " + roiManager("Count") + " ROI");
		print("Analysis took " + (getTime - time0)/1000 + " s");
		run("Remove Overlay");
	}
	
	// if there was any kinf of mask retrive the original image
	if(bInclude || remRegions){
		selectWindow(orTitle);
		close();
		selectWindow("START_"+orTitle);
		rename(orTitle);
		run("Remove Overlay");
	}
}

// Now that we have potential particles, detect where they appear	
function detectFrame(){
	/*	
			find the peak(s) using https://sils.fnwi.uva.nl/bcb/objectj/examples/PeakFinder/PeakFinderTool.txt
			not really try to use this instead https://nl.mathworks.com/matlabcentral/answers/180170-sudden-changes-in-data-values-how-to-detect
			which will detect a suddent increase bigger then a certain value
	*/

	// use the "allVes" image as a matrix to retrieve the Z-axis profile
	selectWindow("allVes");
	vesicle = getProfile();
	baseline = Array.slice(vesicle,0,BGframes);
	Array.getStatistics(baseline, baseMin, baseMax, baseMean, baseStdDev);
	FF0 = newArray(vesicle.length);
	for(e=0; e<vesicle.length; e++){
		FF0[e] = vesicle[e] / baseMean;
	}
	vesicle = FF0;
	
	// detection: Rolling -> use a walking STD measure, as soon as the value is higher than the walking noise treat it as a potential spot
	if(bRolling){
		rollStd = newArray(vesicle.length);
		Array.fill(rollStd,0);
		
		// calculate a walking standard deviation
		startFrame = BGframes - 1;
		for(r=startFrame; r<rollStd.length; r++){
			tempArray = Array.slice(vesicle,r - startFrame,r);
			Array.getStatistics(tempArray, tempMin, tempMax, tempMean, tempStd);
			rollStd[r] = tempMean + detSigma * tempStd;
		}
		
		// calculate the difference between the STD and the trace to find the point the goes above
		rollDiff = newArray(vesicle.length);
		Array.fill(rollDiff,0);
		for(r=startFrame; r<rollStd.length; r++){
			rollDiff[r] = vesicle[r] - rollStd[r];
		}
		
		// get the parameter from the baseline as cleaning
		baseArray = Array.slice(vesicle,0,BGframes-1);
		Array.getStatistics(baseArray, baseMin, baseMax, baseMean, baseStd);
		cleanLvl = baseMean + cleSigma * baseStd;
		
		// now check when it goes above 0
		evSlices = newArray(1);
		evSlices[0] = 0;
		for(r=0;r<rollDiff.length;r++){
			if(rollDiff[r] > 0){
				// there is a candidate
				if(vesicle[r] > cleanLvl){
					tempSlice = r + 1;
					if(evSlices.length == 1 && evSlices[0] == 0){
						evSlices[0] = tempSlice;
					} else {
						evSlices = Array.concat(evSlices, tempSlice);
					}
				}
			}
		}
		
		// now update the event
		if(evSlices.length > 1 || evSlices[0] > 0){
			for(e=0;e<evSlices.length;e++){
				if(e==0){
					selectWindow(orTitle);
					setSlice(evSlices[e]);
					bPos = evSlices[e];
				} else {
					// else need to think on how to add new events
				}
			}
		} else {
			// nothing, only a continue bright spot
			bPos = 0;
		}
	} else { // use the first derivative as measure of a sudden change (to be implemented)
		// calculate a F/F0
		if(BGframes == 0){
			BGframes = 30;
			Dialog.create("No baseline");
			Dialog.addMessage("No baseline stated.\nAssumed 30 frames.\nCheck the options");
			Dialog.show;
		}
		baseline = Array.slice(vesicle,0,BGframes);
		Array.getStatistics(baseline, baseMin, baseMax, baseMean, baseStdDev);
		FF0 = newArray(vesicle.length);
		for(e=0; e<vesicle.length; e++){
			FF0[e] = vesicle[e] / baseMean;
		}
		
		// calculate the first derivative
		ves1 = Array.slice(FF0, 0, vesicle.length-1);
		ves2 = Array.slice(FF0, 1, vesicle.length);
		diffVes = newArray(ves1.length);
		for(e=0; e<ves1.length; e++){
			diffVes[e] = ves2[e] - ves1[e];
		}
		
		// estimate a tollerance level
		Array.getStatistics(FF0, FF0min, FF0max, FF0mean, FF0stdDev);
		Array.getStatistics(diffVes, diffMin, diffMax, diffMean, diffStdDev);
		tollerance = diffMean + detSigma * diffStdDev;
		hpMax = Array.findMaxima(diffVes, tollerance);
		if(hpMax.length > 0){
			hpSlice = hpMax[0] + 1; // +1 because of the first derivative
			if(hpSlice > BGframes){
				bTime = true;
			if(hpSlice < FF0.length){
				zValues = Array.slice(FF0, hpSlice-BGframes, hpSlice); // get some information on what happened before
			} else {
				zValues = Array.slice(FF0, hpSlice-BGframes, FF0.length-1);
			}
			Array.getStatistics(zValues, zMin, zMax, zMean, zStdDev);
			zMaxValue = FF0[hpSlice];
			
			// first filter: is it higher than the STD in the FF0 data
			bFF0std = zMaxValue >= (zMean + cleSigma * zStdDev);
			
			// other filters: have to think about it
			bOther = true;
			} else{
				// it is during the baseline, probbly not a good candidate
				bTime = false;
				bFF0std = false;
				bOther = false;
			}
			bPos = bFF0std & bTime & bOther;
			setSlice(hpSlice);
		} else {
			bPos = false;
		}
	}
	return bPos;
}
	

/////////////////////////////////////////////
/////////ROI MODIFICATION FUNCTIONS/////////
////////////////////////////////////////////

// save the Roi Manager as a zip file with the proper name in the proper folder
function SaveROIs(){
	if (folder == "Current Folder"){
  		wd = getDirectory("Image");
  	} else if (folder == "Specific Folder"){
  			wd = getDirectory("Choose a Directory");
  	} else if (folder == "New Folder"){
  		wd = getDirectory("Choose a Directory");
  	}
	
	fullname = getTitle; // get the file name of the image
	if ((endsWith(fullname, ".stk")) || (endsWith(fullname, ".tif"))){
		fullname = substring(fullname, 0, lengthOf(fullname)-4);
		} else {
			if (endsWith(fullname, ".tiff")){
				fullname = substring(fullname, 0, lengthOf(fullname)-5);
			}
		}
	
	if (saveas == "cs and cell ID"){
		name = substring(fullname, lengthOf(fullname)-7, lengthOf(fullname)); //retrive the last part of the name (cs and cell number)
	} else {
		name = fullname;
	}
	roiManager("Save", wd + "RoiSet_" + name + ".zip");
}

// basically the Roi Manager multimeasure option, plus copy already the table and save automatically (in case)
function MeasureEvents(){
	if (Autosave == 1)
		SaveROIs();
	if (InvertedLUT == 1)
		run("Invert", "stack");
	resetMinAndMax();
	roiManager("Deselect");
	roiManager("Multi Measure");
	String.copyResults();
	String.copyResults();
}

// Add or remove Roi manually
function PlaceROIs(){
	getCursorLoc(x, y, z, flags);
	x1 = x - floor(ROI_size / 2);
	y1 = y - floor(ROI_size / 2);
	
	// Use the flag "Alt" to find the Roi in the Manager and delete it
	if (isKeyDown("alt")){
		nROI = roiManager("count");
		r = 0;
		while((r < nROI) && (bROI == 0)){
			roiManager("Select", r);
			bROI = selectionContains(x, y);
			r++;
		}
		if (bROI == 1)
			roiManager("Delete");
	}else{
		// add roi acconding to shape and size
		if (ROI_shape == "Rectangle"){
			makeRectangle(x1, y1, ROI_size, ROI_size);
		} else {
			makeOval(x1, y1, ROI_size, ROI_size);
		}
	if (Autoadd == 1){
		roiManager("Add");
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ROIs reader functions

function MovetoROI(){ //Move the field of view to the specific ROI number, with the possibility to fully zoom in
	moveToROI();
}

function start(){
	waitForUser("Move to ROI", "OK to choose a new one \n alt + OK to close"); 
	if (isKeyDown("alt")){
		setKeyDown("none");
	} else {
		moveToROI();
	}
}

function moveToROI() {
	//Ask for the ROI number
	Dialog.create("ROI number");
	Dialog.addNumber("ROI number", 1);
	Dialog.show;
	nframes = Dialog.getNumber();
	nframe = nframes - 1;

	//Check that we are in range
	nROI  = roiManager("count");
	if (nframe > nROI){
		waitForUser('Warning', 'The number insert is bigger than the ROI file');
		start();
	}

	//Select it
	roiManager("Select", nframe);
	run("To Selection");
	if (MovetoZoom == 0){
		run("Out [-]");
		run("Out [-]");
		run("Out [-]");
		run("Out [-]");
	}
	start();
	}
}

// function to read the frame of the roi
function ROIreader(what){
	//Set the max number of frames
	Dialog.create("Number of frames");
	Dialog.addNumber("Number of frames", 181);
	Dialog.show;
	nframes = Dialog.getNumber();

	//Create an empty new figure as template
	newImage("Untitled", "8-bit black", 512, 512, nframes);

	if (what == "folder"){
		bROI = roiManager("Count");
		if (bROI !=0){
			roiManager("Deselect");
			roiManager("Delete");
		}
		//Getting the folder
		path = getDirectory("Select a Directory");
		list = getFileList(path);

		//Loop through all the RoiSet.zip file in the folder
		for (f=0; f<list.length; f++){
			if (endsWith(list[f], ".zip")){
				file = path+ "\\"+ list[f];
				roiManager("Open", file);
				IJ.log(list[f]);
				readframes();
				roiManager("Deselect");
				roiManager("Delete");
			}
		}
	} else if (what == "file"){
		bROI = roiManager("Count");
		if (bROI !=0){
			roiManager("Deselect");
			roiManager("Delete");
		}
		file = File.openDialog("Select a File");
		roiManager("Open", file);
		readframes();
	} else if (what == "manager"){
		readframes();
	}
	close();
}

function readframes(){
		nROI  = roiManager("count");
		frame = newArray(nROI);
		for(i=0; i<nROI; i++){
			roiManager("Select", i);
			slice = getSliceNumber();
			frame[i] = parseInt(slice);
		}
		Array.print(frame);
}