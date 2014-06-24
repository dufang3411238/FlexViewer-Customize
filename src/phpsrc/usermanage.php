<?php
	$loginStatus = "登陆失败";
	if(isset($_POST[username]) && isset($_POST[userpwd])&& isset($_POST[usertype])){
		$username=$_POST[username];
		$pwd=$_POST[userpwd];
		$utype = $_POST[usertype];
	}else{
		echo '用户名或密码不能为空!';
		exit;
	}

	$conn_string  =  "host=localhost port=5432 dbname=userinfo user=postgres password=123456" ; 
	$dbconn = pg_connect($conn_string);
	if (!$dbconn){ 
		echo "连接失败！\n";
		exit;
	}

	$result = pg_query_params($dbconn, "select id from usersinfo where usertype=$1 and username = $2 and psw=$3", array($utype,$username,$pwd));
	
	if (!$result) {
		echo '配置出错！\n';
		exit;
	}
	
	while ($row = pg_fetch_row($result)) {
		//writeXmlFile(pg_escape_string($row[0]));
		$loginStatus = "success";
	}
    pg_close($dbconn);
	echo $loginStatus;
	
	function writeXmlFile($xmlData){
		
        $path = dirname($_SERVER['DOCUMENT_ROOT']); //获取当前绝对路径
        /*记录完整路径和文件名*/
        $filePathAndName = $path."/www/MyTest/config.xml";
		$filePathAndName = str_replace('/','\\',$filePathAndName);
        /*打开文件*/
        $fp = fopen($filePathAndName, "w");
        if(!$fp)
        {
            return false;
        }
        /*写入文件流*/
        $flag = fwrite($fp, $xmlData);
        if(!$flag)
        {
            return false;
        }
        fclose($fp);
        return $filePathAndName;
    }
?>
