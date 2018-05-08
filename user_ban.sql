CREATE DEFINER=`root`@`%` PROCEDURE `user_ban`(
IN
	steamId VARCHAR(32),
	ip VARCHAR(24),
	name VARCHAR(64),
	banlength INT(11),
	bantype TINYINT(3),
	serverId SMALLINT(3),
	modId SMALLINT(5),
	adminUid INT(11),
	adminName VARCHAR(32),
	reason VARCHAR(128)
)
    SQL SECURITY INVOKER
BEGIN

	DECLARE banT TINYINT(3) DEFAULT 0;
	DECLARE banC INT(11) DEFAULT 0;
	DECLARE banL INT(11) DEFAULT 0;
	DECLARE banS SMALLINT(3) DEFAULT 0;
	DECLARE banM SMALLINT(3) DEFAULT 0;
	DECLARE isBan INT(1) DEFAULT 0;
	
	SELECT `bType`, `bSrv`, `bSrvMod`, `bCreated`, `bLength` INTO `banT`, `banS`, `banM`, `banC`, `banL` FROM `np_bans` WHERE `steamid` = `steamId` AND `bRemovedBy` = -1 ORDER BY `bCreated` DESC LIMIT 1;
	
	IF (ROW_COUNT() > 0) THEN
		IF (banC+banL > UNIX_TIMESTAMP(NOW()) OR !banL) THEN
			IF ((banT = 2 AND banS = serverId) OR (banT = 1 AND banM = modId)) THEN
				SET isBan = 1;
			END IF;
		END IF;
    END IF;

	IF (!isBan) THEN
		INSERT INTO `np_bans` VALUES (DEFAULT, `steamId`, `ip`, `name`, UNIX_TIMESTAMP(NOW()), `banlength`, `bantype`, `serverId`, `modId`, `adminUid`, `adminName`, `reason`, -1);	
	END IF;
	
	SELECT isBan;
END