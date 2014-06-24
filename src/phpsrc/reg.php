<?php
	if(isset($_POST[username]) && isset($_POST[userpwd])&& isset($_POST[usertype])){
		$username=$_POST[username];
		$psw =$_POST[userpwd];
		$usertype = $_POST[usertype];
	}else{
		echo '用户名或密码不能为空!';
		exit;
	}
	
	$userrealname = $_POST[userrealname];
	$userdep = $_POST[userdep];
	$usertel = $_POST[usertel];
	$usermail = $_POST[usermail];

	$conn_string  =  "host=localhost port=5432 dbname=userinfo user=postgres password=123456" ; 
	$dbconn = pg_connect($conn_string);
	if (!$dbconn){ 
		echo "更新失败！\n";
		//echo "连接失败！\n";
		exit;
	}

	$result = pg_query_params($dbconn, "insert into usersinfo('username','psw','usertype','userrealname','userdep','usertel','usermail') values($1,$2,$3,$4,$5,$6)",
							array($username,$psw ,$usertype,$userrealname,$userdep,$usertel,$usermail));
	if (!$result) {
		//echo '配置出错！\n';
		echo "更新失败！\n";
		exit;
	}
	
	$cmdtuples = pg_affected_rows($result);

	
	pg_close($dbconn);
	echo $cmdtuples;
	
?>
