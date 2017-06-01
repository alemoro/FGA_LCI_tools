// Emgu_processing
/*
This toolset implement the pHluorin toolset with options to combine with the Emgu fusion detection (.net).
It will have different option instead of only one option files, depending on what the user will click.

Start developing 2015.12.01

Modify           
	2016.01.22 - Add new function: export to SynD in both mCherry and pHluorin
	2016.02.03 - bugs fixed in export to SynD
	2016.12.08 - Add new function: automatic detection
	2016.12.09 - Test automatic detection; add filter for detection; modify the "Option" file
	2016.12.13 - Bug correction and plugin checks
	2017.01.08 - Update detection function
	2017.01.17 - Cleanup code and extract function
	2017.01.18 - Rename to project Heaven (debug and implement new parameter)
	2017.01.19 - Add option for detect ROI in a selection
	2017.05.01 - Add option for detect ROI every N frames
*/

var majVer = 1;
var minVer = 91;
var about = "Developed by Alessandro Moro<br>"
			+ "<i>Department of Functional Genomic Analysis</i> (FGA)<br>"
			+ "<i>Centre of neuroscience and cognitive research</i> (CNCR)<br>"
			+ "<i>Vrij Universiteit</i> (VU) Amsterdam.<br><br><br>";

// Initialize the variables
var fOption;
var wd = getDirectory("Image");
var	InvertedLUT;
var	StartZoom;
var AlignStack;
var	Autoadd;
var	ROI_size;
var	ROI_shape;
var	saveas;
var	folder;
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

// even before starting check if it's the first time it's run
bFirst = call("ij.Prefs.get", "detectionPar.bFirst", true);
if(bFirst == 1){
	setDefaultParameters(false);
	call("ij.Prefs.set", "detectionPar.bFirst", false);
}


// leave one empty slot
macro "Unused Tool -1-" {} 

// Start Analysis -> Change LUT, performe BG subtraction or save file to Emgu
var sCmds1 = newMenu("Start Analysis Menu Tool", newArray("Project Heaven", "Save to Emgu", "Export to SynD", "-", "Options"));
macro "Start Analysis Menu Tool - C555T1d13 T9d13 R01fbR2397 Cd00T1d13 T9d13 D00D01D02D03D0dD0eD0fD10D11D12D13D14D1cD1dD1eD1fD20D21D24D25D2bD2cD2eD2fD30D31D35D36D3aD3bD3eD3fD40D41D46D47D49D4aD4eD4fD50D51D57D58D59D5eD5fD60D61D68D6eD6fD70D71D7eD7fD80D81D82D83D8cD8dD8eD8fD90D91D92D93D9cD9dD9eD9f"{
	cmd1 = getArgument();
	Begin();
	if (cmd1 == "Options")
		Options();
	else if (cmd1 == "Save to Emgu"){		
		SaveToEmgu();
	}
	else if (cmd1 == "Project Heaven"){
		title = getTitle();
		StartAnalysis(title);
	}
	else if (cmd1 == "Export to SynD"){
		exportToSynD();
	}
}

// Place ROIs -> automatically with defined size, shape and add them to ROI manager, double click for specific options
macro "Place ROIs Tool -C5d5T1d13 T9d13 R0977 Cdd0T1d13 T9d13 D1dD2aD2bD2cD37D38D39D3aD3bD3eD43D44D45D46D47D48D49D4aD4dD4eD53D54D55D56D57D58D59D5cD5dD63D64D65D66D67D68D6bD6cD6dD73D74D75D76D77D7aD7bD7cD7dD84D85D86D87D89D8aD8bD8cD92D93D95D96D97D98D99D9aD9bD9cDa1Da2Da3Da4Da6Da7Da8Da9DaaDabDacDb2Db3Db4Db5Db7Db8Db9DbaDbbDbcDc3Dc4Dc5Dc6Dc8Dc9DcaDcbDccDd4Dd5Dd6De5De6"{
	Begin();
	PlaceROIs();
}
macro "Place ROIs Tool Options ..."{
	Begin();
	shapes = newArray("Rectangle", "Oval");
	Dialog.create("ROI shape'n'size ");
	Dialog.addRadioButtonGroup("Shape", shapes, 1, 2, ROI_shape);
	Dialog.addSlider("Size", 1, 10, ROI_size);
	Dialog.show();
	NewShape = Dialog.getRadioButton();
	NewSize  = Dialog.getNumber();
	ROI_shape = NewShape;
	ROI_size  = NewSize;
	SaveOptions();
}


// Save ROIs -> with the proper name, cs and cell ID or full name, in the proper folder
var sCmds2 = newMenu("ROIs Interacion Menu Tool", newArray("Import from Emgu", "Save ROI", "Measure ROIs", "Move through ROIs", "-", "Options"));
macro "ROIs Interacion Menu Tool - C5d5T1d13 T9d13 R9077  C555T1d13 T9d13 D2aD3aD3bD4aD4bD4cD50D51D52D53D54D55D56D57D58D59D5aD5bD5cD5dD60D61D62D63D64D65D66D67D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D77D78D79D7aD7bD7cD7dD7eD7fD80D81D82D83D84D85D86D87D88D89D8aD8bD8cD8dD8eD90D91D92D93D94D95D96D97D98D99D9aD9bD9cD9dDaaDabDacDbaDbbDca"{
	cmd2 = getArgument();
	Begin();
	if (cmd2 == "Import from Emgu")
		ImportFromEmgu();
	else if (cmd2 == "Save ROI")
		SaveROIs();
	else if (cmd2 == "Measure ROIs")
		MeasureEvents();
	else if (cmd2 == "Move through ROIs")
		MovetoROI();
	else if (cmd2 == "Options")
		Options();
}

// ROIs frames -> read all the RoiSet.zip file in the specified folder reporting the name and frame number
var sCmds3 = newMenu("ROIs Frames Reader Menu Tool", newArray("From ROI Manager", "From File", "From Folder"));
macro "ROIs Frames Reader Menu Tool - C5d5T1d13 T9d13 R9077R9977 C555T1d13 T9d13 L00f0L03f3L06f6L09f9L0cfcL0fbf"{
	cmd3 = getArgument();
	if (cmd3 == "From ROI Manager"){
		what = "manager";
		ROIreader(what);
	}
	else if (cmd3 == "From File"){
		what = "file";
		ROIreader(what);
	}
	else if (cmd3 == "From Folder"){
		what = "folder";
		ROIreader(what);
	}
}

// Documentation!!!
macro "Help... Action Tool - C000D84Cb9fD25De7CaaaD14D2dDa0DafDecDfaCedfD49D4aD4bD4cD58D68D9bDb9DbaDbbDbcC889D2cDebCddfD52CcccD0bD22CeeeD00D03D0cD0fD10D1fD20D2fD30D40Dc0Dd0DdfDe0DefDf0Df1Df2Df3DfcDfeDffC666D07D70CdcfD34D35Dc4CbacD86D91CfefD6bD6dD7cD8cD8dD8eD9cD9dDadC97aDd3De5CedfD99CeeeD01D02D04D0dD0eD11D12D1eD21D3fDcfDd1De1De2DeeDf4DfdCfefD7dC545D94Da5CdbeDa4Da7CbabD05D50DaeCfefD7eC98aD32Da1CecfD39D3aD3bD46D48D57D67Da8Db6Db8Dc9DcaDcbDccCdcdD81C878D1bD60D65CdcfD29D36D38D47D77Db7Dc8Dd9DdaCcbcD7aDbfDc1De3C98bD16D24D75DeaCedfD56D66D73D76D83D93Da3C212D7bD88D96D97CcaeD26D3cDdbCaaaD3eD5fCfdfD59C889D15D1aD78Dc2CdcfD45Db4Db5Dc6CdddD13D31D4fDdeDedDfbC777D09D7fD85D90Df7CeceDbdCbadD18D55Db2De9Ca9aD5eDcdDceDdcC656D08D64D80D87D8bCdbfD28D2aD37Dc7Dd8CbbbD1cD42Dd2Df5CfdfD5aD5bD5cD5dD69D6aD6cD9aDa9DabDacC999D0aD41DddDf6CdddD1dD2eD9eDb0C888D06D4eD6fD9fDf9CcbdD54D71D98Dc3Ca9dD17D19Dd4De6C000D74D79D95CcafDd5Dd6De8CedfD62D72D92C889D51Db1DbeCedfD53D63Da2CdcdD6eC777D8fDf8CdcfD43D44Db3Dc5CbadD2bD33C99aD23De4C545D89Da6CcbfD27Dd7CbabD61CedfD82DaaC98aD3dCdceD4dD8a"{
	message = "<html>"
	 + "<h2>Version " + majVer + "." + minVer + "</h2><br>"
	 + about + "<br>"
	 + "<b>Documentation still in progress.</b><br>"
	 + "For a short description see:<br>"
	 + "<a href=\"https://drive.google.com/file/d/0BzAbxlpmXmqiYTR4Q3dfNTIwWWM/view?usp=sharing\">this presentation.</a><br>"
	 + "Click <a href=\"http://1drv.ms/1PgbMxn\">here</a> for the version log.";
	Dialog.create("Help");
	Dialog.addMessage("Version " + majVer + "." + minVer + ", \nclick \"Help\" for more");
	Dialog.addHelp(message);
	Dialog.show;
	//showMessage("Not very usefull", message);
}

//////////////////////////////////////////////
////////////// Function list /////////////////
/////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// General functions
function Begin(){ // Retrive the saved options and in case ask for them
	if (File.exists(getDirectory("macros") + "\pHluorinToolsetOption.txt")) {
		NewOption = GetOptions();
		if (NewOption == 1)
			NewStart();
	} else {
		NewStart();
	}
}
function Options(){ // Start the option dialog
	title = getTitle();
	if (!endsWith(title, ".tif")){
		rename(title + ".tif");
	}
	if (File.exists(getDirectory("macros") + "\pHluorinToolsetOption.txt")) {
		NewOption = GetOptions();
		if (NewOption == 0) {
			SetOptions();
		}
	} else {
		NewStart();
	}
}

function GetOptions(){ // Retrives the options from the storage file
	fOption = File.openAsString(getDirectory("macros") + "\pHluorinToolsetOption.txt");
	rows = split(fOption, "\n");
	if (lengthOf(rows) != 11){
		return 1;	
	} else {		
		BGframes = parseInt(rows[0]);
		InvertedLUT  = parseInt(rows[1]);
		StartZoom    = parseInt(rows[2]);
		AlignStack   = parseInt(rows[3]);
		Autoadd      = parseInt(rows[4]);
		ROI_size     = parseInt(rows[5]);
		ROI_shape    = rows[6];
		savename     = parseInt(rows[7]);
		folder       = rows[8];
		Autosave     = parseInt(rows[9]);
		MovetoZoom   = parseInt(rows[10]);
	
		if (savename == 0){
  			saveas = "cs and cell ID";
  		} else {
  			saveas = "fullname";
  		}
  		return 0;
	}
}

function SaveOptions(){ // Saves it
	fOption = File.open(getDirectory("macros") + "\pHluorinToolsetOption.txt");
	if (saveas == "cs and cell ID"){
  		savename = 0;
  	} else {
  		savename = 1;
  	}
	print(fOption, BGframes);
	print(fOption, InvertedLUT);
	print(fOption, StartZoom);
	print(fOption, AlignStack);
	print(fOption, Autoadd);
	print(fOption, ROI_size);
	print(fOption, ROI_shape);
	print(fOption, savename);
	print(fOption, folder);
	print(fOption, Autosave);
	print(fOption, MovetoZoom);
}

function SetOptions(){ // Real function for the options dialog
  	Dialog.create("pHluorin Analysis Option");
  	Dialog.addNumber("BG frames:", BGframes);
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
	BGframes = Dialog.getNumber();
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
  	if (saveas == "cs and cell ID"){
  		savename = 0;
  	} else {
  		savename = 1;
  	}
  	SaveOptions();
}

function NewStart(){ // No preferences, create a new set of options
	Dialog.create("pHluorin Analysis Option");
	Dialog.addNumber("BG frames:", 0);
	Dialog.addCheckbox("Inverted LUT", 1);
	Dialog.addCheckbox("Zoom in at start", 0);
	Dialog.addCheckbox("Align stack", 1);
	Dialog.addMessage("Place ROI Options:");
	Dialog.addCheckbox("Auto add ROI", 1);
	Dialog.addNumber("ROI size:", 3);
	Dialog.addChoice("ROIs shape:", newArray("Rectangle", "Oval"), "Rectangle");
	Dialog.addMessage("Save Options:");
	Dialog.addChoice("Save ROIs as:", newArray("cs and cell ID", "fullname"), "cs and cell ID");
	Dialog.addChoice("Save ROI in:" ,newArray("Current Folder", "Specific Folder", "New Folder"), "Current Folder");
	Dialog.addCheckbox("Autosave after measuring", 1);
	Dialog.addMessage("Move to ROI Options:");
	Dialog.addCheckbox("Full zoom to ROI", 0);
	Dialog.show();
	BGframes = Dialog.getNumber();
	InvertedLUT = Dialog.getCheckbox();
	StartZoom   = Dialog.getCheckbox();
	AlignStack  = Dialog.getCheckbox();
	Autoadd     = Dialog.getCheckbox();
	ROI_size    = Dialog.getNumber();
	ROI_shape   = Dialog.getChoice();
	saveas      = Dialog.getChoice();
  	folder      = Dialog.getChoice();
  	Autosave    = Dialog.getCheckbox();
  	MovetoZoom  = Dialog.getCheckbox();
  	if (saveas == "cs and cell ID"){
  		savename = 0;
  	} else {
  		savename = 1;
  	}
  	SaveOptions();
}

function cleanupRoiManager(arg){
	print("Cleaning ROI Manager from overlaps");
	nTouch = 4;
	if(arg){nTouch = roiOver;}
	nRoi =roiManager("count");
	r = 0;
	while(r<nRoi){
		showProgress(-(r+1),nRoi);
		showStatus("Cleaning Roi Manager");
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
				if(bROI > nTouch){
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
	cleaned = "ROI Manager cleaned";
	return cleaned;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Start Analysis Menu functions
function StartAnalysis(title){
	detectParticles();
	if (InvertedLUT == 1){
		run("Invert", "stack");
	}
	if (AlignStack == 1){
		run("StackReg", "transformation=[Translation]");
	}
	if (StartZoom == 1){
		run("In [+]");
		run("In [+]");
	}
}

function setDefaultParameters(arg){
	call("ij.Prefs.set", "detectionPar.nh4Start", 161);
	call("ij.Prefs.set", "detectionPar.bBaseline", false);
	call("ij.Prefs.set", "detectionPar.bRolling", true);
	call("ij.Prefs.set", "detectionPar.bgFrames", 30);
	ds = newArray(false, false, true, false, false, false);
	for(d=0;d<6;d++){
		call("ij.Prefs.set", "detectionPar.detSizes"+d, ds[d]);
	}
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
	if(arg){detectionParameters();}
}

function detectionParameters(){
	// get the parameters
	nh4Start = call("ij.Prefs.get", "detectionPar.nh4Start", true);
	bBaseline = call("ij.Prefs.get", "detectionPar.bBaseline", true);
	bRolling = call("ij.Prefs.get", "detectionPar.bRolling", true);
	BGframes = call("ij.Prefs.get", "detectionPar.bgFrames", true);
	for(d=0;d<6;d++){
		detSizes[d] = call("ij.Prefs.get", "detectionPar.detSizes"+d, true);
	}
	snr = call("ij.Prefs.get", "detectionPar.snr", true);
	sigma = call("ij.Prefs.get", "detectionPar.sigma", true);
	detSigma = call("ij.Prefs.get", "detectionPar.detSigma", true);
	cleSigma = call("ij.Prefs.get", "detectionPar.cleSigma", true);
	roiOver = call("ij.Prefs.get", "detectionPar.roiOver", true);
	gapFrames = call("ij.Prefs.get", "detectionPar.gapFrames", true);
	bRecursively = call("ij.Prefs.get", "detectionPar.bRecursively", true);
	nIteration = call("ij.Prefs.get", "detectionPar.nIteration", true);
	bInclude = call("ij.Prefs.get", "detectionPar.bInclude", true);
	
	Dialog.create("Detection options")'
	Dialog.addNumber("Start of NH4 (frame)", nh4Start);
	Dialog.addSlider("Num of gap frames", 1, 5, gapFrames);
	Dialog.addCheckbox("Baseline subtraction?", bBaseline);
	Dialog.addCheckbox("Rolling STD?", bRolling);
	Dialog.addNumber("Baseline frames", BGframes);
	Dialog.addMessage("Estimate size of particles (in px)");
	Dialog.addCheckboxGroup(2,3,sizes,detSizes);
	Dialog.addChoice("Signal to noise", sensitivity);
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
	for(i=0; i<6; i++){
		detSizes[i] = Dialog.getCheckbox();
	}
	snr = Dialog.getChoice();
	sigma = Dialog.getNumber();
	detSigma = Dialog.getNumber();
	cleSigma = Dialog.getNumber();
	remRegions = Dialog.getCheckbox();
	advOption = Dialog.getCheckbox();

	// set the new parameters
	call("ij.Prefs.set", "detectionPar.nh4Start", nh4Start);
	call("ij.Prefs.set", "detectionPar.gapFrames", gapFrames);
	call("ij.Prefs.set", "detectionPar.bBaseline", bBaseline);
	call("ij.Prefs.set", "detectionPar.bRolling", bRolling);
	call("ij.Prefs.set", "detectionPar.bgFrames", BGframes);
	for(d=0;d<6;d++){
		call("ij.Prefs.set", "detectionPar.detSizes"+d, detSizes[d]);
	}
	call("ij.Prefs.set", "detectionPar.snr", snr);
	call("ij.Prefs.set", "detectionPar.sigma", sigma);
	call("ij.Prefs.set", "detectionPar.detSigma", detSigma);
	call("ij.Prefs.set", "detectionPar.cleSigma", cleSigma);

	// check if the advance options are checked
	if(advOption){
		Dialog.create("Advance detenction option");
		Dialog.addNumber("ROI overlap", roiOver)
		Dialog.addCheckbox("Run recursively (experimental)", bRecursively);
		Dialog.addSlider("Number of iteration", 1, 5, nIteration);
		Dialog.addCheckbox("Detect at selection", bInclude);
		Dialog.addCheckbox("Reset parameters", false);
		Dialog.addNumber("Detect every N frames", detectEvery);
		Dialog.show();
		roiOver = Dialog.getNumber();
		bRecursively = Dialog.getCheckbox();
		nIteration = Dialog.getNumber();
		bInclude = Dialog.getCheckbox();
		bReset = Dialog.getCheckbox();
		detectEvery = Dialog.getNumber();
		if(bReset){
			setDefaultParameters(true);
		} else {
			call("ij.Prefs.set", "detectionPar.roiOver", roiOver);
			call("ij.Prefs.set", "detectionPar.bRecursively", bRecursively);
			call("ij.Prefs.set", "detectionPar.nIteration", nIteration);
			call("ij.Prefs.set", "detectionPar.bInclude", bInclude);
			call("ij.Prefs.set", "detectionPar.detectEvery", detectEvery);
		}
	}
}

function detectParticles(){
	// first check if the correct plugin is installed
	pluginDir = getDirectory("plugins");
	plugins = getFileList(pluginDir);
	for(p=0;p<plugins.length;p++){
		tempP = plugins[p];
		bDetection = indexOf(tempP, "ComDet_") >= 0;
		if(bDetection)	p = plugins.length;
	}
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
		// first apply a stack subtraction
		orTitle = getTitle();
		detectionParameters();
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
			// Start getting the MAX_diff image
			selectWindow(orTitle);
			if(!bInclude){
				run("Select None");
			} else {
				if(iter == 0){
					rename("START_"+orTitle);
					run("Select None");
					run("Duplicate...", "duplicate");
					rename(orTitle);
					run("Restore Selection");
					run("Clear Outside", "stack");
				}
			}
			if(remRegions && iter == 0){
				setTool("polygon");
				rename("START_"+orTitle);
				run("Select None");
				run("Duplicate...", "duplicate");
				rename(orTitle);
				while(!isKeyDown("shift")){
					waitForUser("Trace region to exclude.\nTo add a new line click \"OK\".\nTo continue click shift+\"OK\"");
					if(isKeyDown("shift")){
						setKeyDown("none");
						setForegroundColor(255, 0, 255);
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
			// check for iterations
			if(iter > 0){
				arg = true;
				for(r=0;r<roiManager("count");r++){
					roiManager("Select", r); 
					run("Fill", "stack");// try to hide the previous detected roi
				}
			}
			setPasteMode("Subtract");
			selectWindow("tempDiff");
			run("Gaussian Blur 3D...", "x=" + sigma +" y=" + sigma +" z=" + sigma);
			run("Set Slice...", "slice="+nSlices);
			run("Select All");
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
			//run("Differentials");
			run("Min...", "value=1 stack"); // to avoid 0 in pixel values
			if(bBaseline){
				// get a baseline image
				run("Duplicate...", "duplicate range=1-" + BGframes);
				rename("BaseStk");
				run("Z Project...", "projection=[Max Intensity]");
				rename("BaseImg");
				selectWindow("BaseStk");
				close();
				imageCalculator("Divide create stack", "Diff_" + orTitle, "BaseImg");
				rename("ff0Stk");
				selectWindow("Diff_" + orTitle);
				close();
				selectWindow("BaseImg");
				close();
				selectWindow("ff0Stk");
				//getStatistics(area, diffMean, min, max, std, histogram);
				//run("Min...", "value=" + diffMean + " stack");
			}
			// run("Gaussian Blur...", "sigma=" + sigma + " stack");
			// Detect every N frames, so split the image and collect all the ROIs
			nSub = 1;
			for(nF=1; nF<nh4Start; nF += detectEvery){
				print("Analyze sub movie: " + nSub);
				nSub++;
				selectWindow("Diff_" + orTitle);
				run("Duplicate...", "duplicate range=" + nF + "-" + (nF+detectEvery));
				rename("subTempImg");
				run("Z Project...", "projection=[Max Intensity]");
				run("16-bit");
				rename("tempMax");
				selectWindow("subTempImg");
				close();
				selectWindow("tempMax");
				// then particles detection: ask for sensitivity and size	
				selectWindow("tempMax");
				run("Morphological Filters", "operation=[White Top Hat] element=Disk radius=2");
				selectWindow("tempMax");
				close();
				selectWindow("tempMax-White Top Hat");
				rename("tempMax");
				// check if there are already ROIs or if it's the first time
				arg = roiManager("count") > 0;
				for(d=0; d<6; d++){
					apx = detSizes[d] * sizes[d];
					if(apx > 0){
						sens = snr;
						run("Detect Particles", "approximate="+apx+" sensitivity=["+sens+"]");
						// get the center point of the particles
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
				selectWindow("Results");
				run("Close");
				selectWindow("Summary");
				run("Close");
				aa = cleanupRoiManager(arg);
				print(aa);
				selectWindow("tempMax");
				close();
				selectWindow(orTitle);
				run("Remove Overlay");
				wait(10);
			}
			if(bBaseline){
				selectWindow("ff0Stk");
				close();
			} else {
				selectWindow("Diff_" + orTitle);
				close();
			}
			// try to clean the ROI manager from false positive
			
			nRoi = roiManager("count");
			r = 0;
			
			while(r<nRoi){
				showProgress(r+1,nRoi);
				showStatus("Cleaning Roi Manager");
				roiManager("Select",r);
				bPos = detectFrame(nh4Start);
				if(bPos){
					//we have a positive candidate
					roiManager("Update");
					r++;
				} else {
					roiManager("Delete");
					nRoi -= 1;
				}
			}
			run("Select None");
		}
		if(ROI_size < 3){
			refineRoi(true);
		}
		aa = cleanupRoiManager(arg);
		print(aa);
		print("Succesfully placed " + roiManager("Count") + " ROI");
		print("Analysis took " + (getTime - time0)/1000 + " s");
	}
	if(bInclude || remRegions){
		selectWindow(orTitle);
		close();
		selectWindow("START_"+orTitle);
		rename(orTitle);
	}
}

function refineRoi(bAll){
	nRoi = roiManager("Count");
	mean = newArray(4);
	for(r=0;r<nRoi;r++){
		if(bAll){
			roiManager("Select", r);
		}
		Roi.getBounds(x0, y0, w0, h0);
		makeRectangle(x0, y0, 2, 2);
		getStatistics(a, mean[0], m, M, std, h);
		makeRectangle(x0+1, y0, 2, 2);
		getStatistics(a, mean[1], m, M, std, h);
		makeRectangle(x0, y0+1, 2, 2);
		getStatistics(a, mean[2], m, M, std, h);
		makeRectangle(x0+1, y0+1, 2, 2);
		getStatistics(a, mean[3], m, M, std, h);
		max = Array.findMaxima(mean,10);
		if(max.length > 0){
			if(max[0] == 0){
				makeRectangle(x0, y0, 2, 2);
				roiManager("Update");
			} if(max[0] == 1){
				makeRectangle(x0+1, y0, 2, 2);
				roiManager("Update");
			} if(max[0] == 2){
				makeRectangle(x0, y0+1, 2, 2);
				roiManager("Update");
			} if(max[0] == 3){
				makeRectangle(x0+1, y0+1, 2, 2);
				roiManager("Update");
			}
		} else {
			roiManager("Delete");
			nRoi -= 1;
		}
		if(!bAll){
			r = nRoi;
		}
	}
}


	
function detectFrame(nh4Start){
	/*	
			find the peak(s) using https://sils.fnwi.uva.nl/bcb/objectj/examples/PeakFinder/PeakFinderTool.txt
			not really try to use this instead https://nl.mathworks.com/matlabcentral/answers/180170-sudden-changes-in-data-values-how-to-detect
			which will detect a suddent increase bigger then a certain value
	*/
	vesicle= newArray(nh4Start-1);
	for(z=1; z<=nh4Start-1; z++){
		setSlice(z);
		getRawStatistics(nPixels, vMean, vMin, vMax, vStd, vHistogram);
		vesicle[z-1] = vMean;
	}
	baseline = Array.slice(vesicle,0,BGframes);
	Array.getStatistics(baseline, baseMin, baseMax, baseMean, baseStdDev);
	FF0 = newArray(vesicle.length);
	for(e=0; e<vesicle.length; e++){
		FF0[e] = vesicle[e] / baseMean;
	}
	vesicle = FF0;
	if(bRolling){
		rollStd = newArray(vesicle.length);
		Array.fill(rollStd,0);
		// calculate a rolling standard deviation
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
		// now add the events
		if(evSlices.length > 1 || evSlices[0] > 0){
			for(e=0;e<evSlices.length;e++){
				if(e==0){
					setSlice(evSlices[e]);
					bPos = true;
				} else {
					// else need to think on how to add new events
					/*
					if(evSlices[e] - evSlices[e-1] > 1){
						roiIdx = roiManager("index");
						print("Extra event detected for ROI: " + roiIdx + 1);
						setSlice(evSlices[e]);
						Roi.getBounds(xS,yS,wS,hS);
						nNew = 4;
						xN = newArray(nNew);
						yN = newArray(nNew);
						mN = newArray(nNew+1);
						xN[0] = xS-1; xN[1] = xS+1; xN[2] = xS+1; xN[3] = xS-1;
						yN[0] = yS-1; yN[1] = yS-1; yN[2] = yS+1; yN[3] = yS+1;
						//
							xN[0] = xS-(wS); xN[1] = xS-(wS/2); xN[2] = xS; xN[3] = xS+(wS/2); xN[4] = xS+wS; xN[5] = xS+wS;
							xN[6] = xS+wS; xN[7] = xS+wS; xN[8] = xS+wS; xN[9] = xS+(wS/2); xN[10] = xS; xN[11] = xS-(wS/2);
							xN[12] = xS-wS; xN[13] = xS-wS; xN[14] = xS-wS; xN[15] = xS-wS;
							yN[0] = yS-hS; yN[1] = yS-hS; yN[2] = yS-hS; yN[3] = yS-hS; yN[4] = yS-hS; yN[5] = yS-(hS/2);
							yN[6] = yS; yN[7] = yS+(hS/2); yN[8] = yS+hS; yN[9] = yS+hS; yN[10] = yS+hS; yN[11] = yS+hS;
							yN[12] = yS+hS; yN[13] = yS+(hS/2); yN[14] = yS; yN[15] = yS-(hS/2);
						//
						getStatistics(area, mN[0], min, max, std, histogram); // consider the already existing location
						for(nn=0;nn<nNew;nn++){
							makeRectangle(xN[nn], yN[nn], wS+1, hS+1);
							getStatistics(area, mN[nn+1], min, max, std, histogram);
						}
						newMax = Array.findMaxima(mN,10);
						if(newMax.length > 0){
							who = newMax[0];
							if(who>0){
								makeRectangle(xN[who-1], yN[who-1], wS, hS);
								roiManager("Add");
							}
						}
						bPos = true;
					}
					*/
				}
			}
		} else {
			bPos = false;
		}
	} else {
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
	
function SaveToEmgu(){
	// Ask what kind of modification has to performed
	itemsLUT = newArray("Grays", "Green");
	itemsKER = newArray("None", "F/F0");
	Dialog.create("TIF to EMGU converter");
	Dialog.addRadioButtonGroup("Lookup table", itemsLUT, 1, 2, "Grays");
	Dialog.addRadioButtonGroup("Filter", itemsKER, 1, 2, "None");
	Dialog.addCheckbox("Process folder?", 0);
	Dialog.show();
	EmguLUT = Dialog.getRadioButton();
	EmguKER = Dialog.getRadioButton();
	Bfolder = Dialog.getCheckbox();
	
	if (EmguKER == 'F/F0'){
		baseFrames = getNumber("How many frames to average for Fzero?", 10);
	} else {
		baseFrames = 1;
	}
	
	if (Bfolder == 1){
		// Get the working folders
		work_path = getDirectory("Select Working directory");
		save_path = getDirectory("Select Saving folder");
		path_list = getFileList(work_path);
		nfile     = path_list.length;
		
		// Add a status bar (just because it's cool)
		titleBar = "[We're working for you]";
		run("Text Window...", "name="+ titleBar +" width=50 height=2 monospaced");

		// Work in batch mode to allow better use of the RAM
		setBatchMode(true);

		// Loop through all the file
		for (f = 0; f < nfile; f++){
			// Update the status bar
			print(titleBar, "\\Update:" + (f+1) + "/" + nfile + " (" + ((f+1)* 100) / nfile + "%)\n" + getBar((f+1), nfile));
	
			// retrive the file and check if it a lsm image
			f_path = work_path + path_list[f];
			if (endsWith(f_path, ".tif")) {
				open(f_path);
				title = getTitle();
				selectWindow(title);

				// select witch method to enhance the contrast
				run("Remove Overlay");
				resetMinAndMax();
				emguKernel(EmguKER, baseFrames, title);
				selectWindow("Processed");
				run("8-bit");
				run(EmguLUT);
				saveas = substring(title, 0, lengthOf(title) - 4);
				run("AVI... ", "compression=Uncompressed frame=2 save=[" + save_path + saveas + EmguLUT + ".avi]");
			}
			while (nImages > 0){
				close();
			}
		}
		// Exit batch mode and close the status bar
		setBatchMode(false);
		print(titleBar, "\\Close");
	} else if (Bfolder == 0){
		wd = getDirectory("Image");
		title = getTitle();
		if (!endsWith(title, ".tif")){
			rename(title + ".tif");
		}
		title = getTitle();
		selectWindow(title);
		setSlice(1);
		resetMinAndMax();
		emguKernel(EmguKER, baseFrames, title);
		selectWindow("Processed");
		run("8-bit");
		run(EmguLUT);
		saveas = substring(title, 0, lengthOf(title) - 4);
		run("AVI... ", "compression=Uncompressed frame=2 save=[" + wd + saveas + EmguLUT + ".avi]");
		close("Processed");
	}
}

function emguKernel(EmguKER, baseFrames, title){
	if (EmguKER == "F/F0"){
		run("Z Project...", "start=1 stop=" + baseFrames + " projection=[Average Intensity]");
		rename("Fzero");
		run("Image Calculator...", "image1=" + title + " operation=Divide image2=Fzero create 32-bit stack");
		rename(title + "-FdivFzero");
		close("Fzero");
		rename("Processed");
	} else if (EmguKER == "Mexican Hat"){
		mexico = "[0 0 -1 0 0\n0 -1 -2 -1 0\n-1 -2 16 -2 -1\n0 -1 -2 -1 0\n0 0 -1 0 0]";
		run("Convolve...", "text1=" + mexico + " normalize stack");
		rename("Processed");
	} else if (EmguKER == "None"){
		run("Duplicate...", "duplicate");
		run("Enhance Contrast", "saturated=0.35");
		run("8-bit");
		rename("Processed");
	}
	return;
}

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
		workDir = getDirectory("Select movies folder");
		saveDir = getDirectory("Select saving folder");
		fileList = getFileList(workDir);
		nFile = fileList.length;
		// Add a status bar (just because it's cool)
		titleBar = "[We're working for you]";
		run("Text Window...", "name="+ titleBar +" width=50 height=2 monospaced");
	
		setBatchMode(true);
		for(f = 0; f < nFile; f++){
			// Update the status bar
			print(titleBar, "\\Update:" + (f+1) + "/" + nFile + " (" + ((f+1)* 100) / nFile + "%)\n" + getBar((f+1), nFile));
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

function saveForSynD(title, marker, startF, endF, Zproj){
	sTitle = substring(title, 0, lengthOf(title) - 4);
	if (marker == "pHluorin"){
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
		//selectWindow(title);
		//run("Duplicate...", "duplicate range=171-181");
		//run("Z Project...", "projection=[Max Intensity]");
		//rename("allResponse");
		//close(sTitle + "-1.stk");
		//close(title);
		//run("Merge Channels...", "c1=allResponse c2=Ammonium create ignore");
	} else {	
		run("Duplicate...", "duplicate range=" + startF + "-" + endF);
		run("Z Project...", "projection=[" + Zproj + "]");
		rename("Average");
		close(sTitle + "-1.tif");
		selectWindow("Average");
	}
	saveAs("Tiff", saveDir + "\\" + sTitle + "_pool.tif");
	//return;
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ROIs modification functions
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

function MeasureEvents(){
	Begin();
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

function PlaceROIs(){
	getCursorLoc(x, y, z, flags);
	x1 = x - floor(ROI_size / 2);
	y1 = y - floor(ROI_size / 2);
	if (isKeyDown("alt")){
		nROI = roiManager("count");
		r = 0;
		do {
			roiManager("Select", r);
			bROI = selectionContains(x, y);
			r = r + 1;
		} while ((r < nROI) && (bROI == 0));
		if (bROI == 1)
			roiManager("Delete");
	}else {
	if (ROI_shape == "Rectangle"){
		makeRectangle(x1, y1, ROI_size, ROI_size);
	} else {
		makeOval(x1, y1, ROI_size, ROI_size);
	}
	if (Autoadd == 1){
		roiManager("Add");
		//bPos = detectFrame(161);
		//if(bPos){
			//we have a positive candidate
			//roiManager("Update");
		//}
	}
}

function ImportFromEmgu(){
	Begin();
	pathfile=File.openDialog("Choose a file");
	filestring=File.openAsString(pathfile);
	rows=split(filestring, "\n");
	x=newArray(rows.length);
	y=newArray(rows.length);
	z=newArray(rows.length);
	r=newArray(rows.length);
	for(i=0; i<rows.length; i++){
		columns=split(rows[i], ";");
		x[i]=parseInt(columns[0]);
		y[i]=parseInt(columns[1]);
		z[i]=parseInt(columns[2]);
		r[i]=parseInt(columns[3]);
		setSlice(z[i]);
		if (ROI_shape == "Rectangle"){
			makeRectangle((x[i] - r[i]/2), (y[i] - r[i]/2), r[i], r[i]);
		} else {
			makeOval(x[i] - r[i]/2, y[i] - r[i]/2, r[i], r[i]);
		}
		roiManager("Add");
	}
	// Try to adjust the size
	
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
	Begin();
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

// status bar function
function getBar(p1, p2) {
	n = 20;
	bar1 = "--------------------------------------------------";
	bar2 = "**************************************************";
	index = round(n*(p1/p2));
	if (index<1) index = 1;
	if (index>n-1) index = n-1;
	return substring(bar2, 0, index) + substring(bar1, index+1, n);
}
