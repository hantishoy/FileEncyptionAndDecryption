// ActionScript file
import deng.fzip.FZip;
import mx.collections.ArrayCollection;
import spark.components.ComboBox;

import flash.events.Event;
import flash.events.MouseEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.FileFilter;
import flash.net.URLLoaderDataFormat;
import flash.utils.ByteArray;

import spark.components.TextInput;

private var file:File;
private var loader:BinaryLoaderManager;
private var selectingPath:TextInput;
private var fileNameArray:Array;
private var fileContentArray:Array;
private var count:int;

private function init():void
{
	file = new File();
	file.addEventListener(Event.SELECT, onDirSelected);
	
	fileNameArray = [];
	fileContentArray = [];
	
	loader = BinaryLoaderManager.getInstance();
	
	cb_Input.dataProvider = new ArrayCollection(LocalSaveManager.getInputDir());
	//cb_Input.text = LocalSaveManager.getURL(LocalSaveManager.DICTIONARY_URL);
	//cb_Output.text = LocalSaveManager.getURL(LocalSaveManager.CONFIG_URL);
	cb_Output.dataProvider = new ArrayCollection(LocalSaveManager.getOutputDir());
	tx_InputZip.text= LocalSaveManager.getURL(LocalSaveManager.ZIP_URL);
	tx_InputURL.text= LocalSaveManager.getURL(LocalSaveManager.TIME_URL);
	
	addEventListener(MouseEvent.CLICK, onClick);
}

protected function onDirSelected(event:Event):void
{
	selectingPath.text = file.nativePath;
}

private function onClick(e:MouseEvent):void
{
	switch (e.target)
	{
		case btn_Scan: 
			selectingPath = cb_Input.textInput;
			file.browseForDirectory("选择文件夹");
			trace("选择路径");
			break;
		
		case btn_ScanZip: 
			selectingPath = tx_InputZip;
			file.browseForOpen("选择需要解密的文件", [new FileFilter("cfg", "*.cfg")]);
			trace("选择路径");
			break;
		
		case btn_ScanURL: 
			selectingPath = tx_InputURL;
			file.browseForDirectory("选择文件夹");
			trace("选择路径");
			break;
		
		case btn_Decryption: 
			if (tx_InputZip.text)
			{
				btn_Decryption.mouseEnabled = false;
				fileDecryption();
			}
			break;
		
		case btn_Encryption: 
			if (cb_Input.textInput.text && cb_Output.textInput.text)
			{
				btn_Encryption.mouseEnabled = false;
				fileEncryption();
			}
			break;
		
		case btn_FileDate: 
			if (tx_InputURL.text)
			{
				btn_FileDate.mouseEnabled = false;
				fileDateWriteInTxt();
			}
			break;
		
		case btn_ScanCfg: 
			selectingPath = cb_Output.textInput;
			file.browseForDirectory("请选择保存的文件位置");
			log("选择cfg或特效文件存放位置");
			break;
		
		default: 
			break;
	}
}

private function fileEncryption():void
{
	//LocalSaveManager.saveURL(cb_Input.text, LocalSaveManager.DICTIONARY_URL);
	//LocalSaveManager.saveURL(cb_Output.text, LocalSaveManager.CONFIG_URL);
	var collection:ArrayCollection = cb_Input.dataProvider as ArrayCollection;
	if (!collection.contains(cb_Input.textInput.text))
	{
		collection.addItem(cb_Input.textInput.text);
	}
	LocalSaveManager.saveInputDir(collection.source);
	collection = cb_Output.dataProvider as ArrayCollection;
	if (!collection.contains(cb_Output.textInput.text))
	{
		collection.addItem(cb_Output.textInput.text);
	}
	LocalSaveManager.saveOutputDir(collection.source);
	file.nativePath = cb_Input.textInput.text;
	if (file.exists)
	{
		var allFile:Array = [];
		getAllFileUrl(file, allFile);
		for (var i:int = 0; i < allFile.length; i++)
		{
			loader.queueLoad(allFile[i], URLLoaderDataFormat.BINARY, onLoadComplete);
		}
	}
}

//加载全部文件
private function getAllFileUrl(dir:File, urlList:Array, prefix:String = ""):void
{
	if (dir && dir.isDirectory)
	{
		var file:File;
		var arr:Array = dir.getDirectoryListing();
		for (var i:int = 0; i < arr.length; i++)
		{
			file = arr[i];
			if (file.isDirectory)
			{
				getAllFileUrl(file, urlList, file.name + "/");
			}
			else
			{
				urlList.push(file.url);
				fileNameArray.push(prefix + file.name);
			}
		}
	}
}

//加载文件完成 对数据进行处理
private function onLoadComplete(data:ByteArray):void
{
	log(fileNameArray[count] + "加载完成");
	count++;
	fileContentArray.push(data);
	var fileStream:FileStream = new FileStream();
	var finalDirectory:File;
	if (count == fileNameArray.length)
	{
		log("所有文件加载完毕：" + count + "个文件加载成功");
		
		if (checkBox_Zip.selected)
		{
			log("开始压缩文件");
			var fileZip:FZip = new FZip();
			for (var i:int = 0; i < count; i++)
			{
				fileZip.addFile(fileNameArray[i], fileContentArray[i]);
			}
			var byteAry:ByteArray = new ByteArray();
			fileZip.serialize(byteAry);
			byteAry.position = 0;
			var encryptedByteAry:ByteArray = encryptionAndDecryption(byteAry, byteAry.length);
			finalDirectory = new File(cb_Output.textInput.text + "/config.cfg");
			fileStream.open(finalDirectory, FileMode.WRITE);
			fileStream.writeBytes(encryptedByteAry);
			fileStream.close();
			log("压缩完成");
		}
		else
		{
			for (var j:int = 0; j < count; j++)
			{
				var filePath:String;
				var nameAry:Array = fileNameArray[j].toString().split(".");
				var simpleEncryptedByteAry:ByteArray
				if (nameAry[1] != "swf" && nameAry[1] !=  "eff") 
				{
					log("格式错误,如果是配置文件请在压缩处点勾");
					resetTool();
					return;
				}
				simpleEncryptedByteAry = encryptionAndDecryption(fileContentArray[j], 100);
				switch (nameAry[1])
				{
					case "swf": 
					{
						filePath = cb_Output.textInput.text + "/" + fileNameArray[j].toString().replace(".swf", ".eff");
						break;
					}
					
					case "eff": 
					{
						filePath = cb_Output.textInput.text + "/" + fileNameArray[j].toString().replace(".eff", ".swf");
						break;
					}
					
					case "mp3": 
					{
						filePath = cb_Output.textInput.text + "/" + fileNameArray[j].toString().replace(".mp3", ".msc");
						break;
					}
					
					case "msc": 
					{
						filePath = cb_Output.textInput.text + "/" + fileNameArray[j].toString().replace(".msc", ".mp3");
						break;
					}
				}
				finalDirectory = new File(filePath);
				fileStream.open(finalDirectory, FileMode.WRITE);
				fileStream.writeBytes(simpleEncryptedByteAry);
				fileStream.close();
				log("格式转换完成");
			}
		}
		resetTool();
	}
}

//文件加密解密
private function encryptionAndDecryption(byteArray:ByteArray, changeByte:int):ByteArray
{
	var min:int = byteArray.length - changeByte > 0 ? changeByte : byteArray.length;
	log(min.toString());
	var encryptionAndDecryptionArray:ByteArray = new ByteArray();
	byteArray.position = 0;
	byteArray.readBytes(encryptionAndDecryptionArray);
	for (var i:int = 0; i < min; i++)
	{
		if ((i & 1) == 0)
		{
			encryptionAndDecryptionArray[i] = ~byteArray[i];
		}
	}
	return encryptionAndDecryptionArray;
}

private function resetTool():void
{
	log("工具重置");
	fileNameArray = [];
	fileContentArray = [];
	btn_Encryption.mouseEnabled = true;
	btn_Decryption.mouseEnabled = true;
	btn_FileDate.mouseEnabled = true;
	count = 0;
}

//文件解密
private function fileDecryption():void
{
	LocalSaveManager.saveURL(tx_InputZip.text, LocalSaveManager.ZIP_URL);
	file.nativePath = tx_InputZip.text;
	if (file.exists)
	{
		var byteAry:ByteArray = new ByteArray();
		var decryptedByteAry:ByteArray = new ByteArray();
		var fileStream:FileStream = new FileStream();
		fileStream.open(file, FileMode.READ);
		fileStream.readBytes(byteAry, 0, 0);
		fileStream.close();
		log("文件读取成功");
		decryptedByteAry = encryptionAndDecryption(byteAry, byteAry.length);
		var finalDirectory:File = File.desktopDirectory.resolvePath(file.name.replace(".cfg", ".zip"));
		fileStream.open(finalDirectory, FileMode.WRITE);
		fileStream.writeBytes(decryptedByteAry, 0);
		fileStream.close();
		log("文件解密成功");
	}
	resetTool();
}

private function fileDateWriteInTxt():void
{
	LocalSaveManager.saveURL(tx_InputURL.text, LocalSaveManager.TIME_URL);
	file.nativePath = tx_InputURL.text;
	if (file.exists && file.isDirectory)
	{
		var dateList:Array = [];
		getFileDate(file, dateList);
	}
	resetTool();
}

private function getFileDate(dir:File, list:Array, prefix:String = ""):void
{
	var fileList:Array = dir.getDirectoryListing();
	var f:File;
	var line:String;
	for (var i:int = 0; i < fileList.length; i++)
	{
		f = fileList[i];
		if (f.isDirectory)
		{
			getFileDate(f, list, f.name + "/");
		}
		else
		{
			line = prefix + f.name + "\t20140331";
			list.push(line);
			trace(line);
		}
	}
}

private function log(logText:String):void
{
	trace(logText);
	tx_Output.appendText(logText + "\n");
}