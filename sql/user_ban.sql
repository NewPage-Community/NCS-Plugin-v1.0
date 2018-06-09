CREATE DEFINER=`root`@`%` PROCEDURE `user_ban`(
IN
	p_steamId VARCHAR(32),
	p_ip VARCHAR(24),
	p_name VARCHAR(64),
	p_banlength INT(11),
	p_bantype TINYINT(3),
	p_serverId SMALLINT(3),
	p_modId SMALLINT(5),
	p_adminUid INT(11),
	p_adminName VARCHAR(32),
	p_reason VARCHAR(128)
)
    SQL SECURITY INVOKER
BEGIN

	DECLARE banC INT(11) DEFAULT 0;
	DECLARE banL INT(11) DEFAULT 0;
	DECLARE isBan INT(1) DEFAULT 0;
    DECLARE ntime INT(11) DEFAULT UNIX_TIMESTAMP(NOW());
	
    IF (bantype = 2) THEN
        SELECT `bCreated`, `bLength` INTO banC, banL FROM `np_bans` WHERE `steamid` = steamId AND `bRemovedBy` = -1 AND `bSrv` = serverId ORDER BY `bCreated` DESC LIMIT 1;
    ELSEIF (bantype = 1) THEN
		SELECT `bCreated`, `bLength` INTO banC, banL FROM `np_bans` WHERE `steamid` = steamId AND `bRemovedBy` = -1 AND `bSrvMod` = modId ORDER BY `bCreated` DESC LIMIT 1;
	END IF;

	IF (ROW_COUNT() > 0) THEN
		IF (banC+banL > ntime OR !banL) THEN
			SET isBan = 1;
		END IF;
    END IF;

	IF (!isBan) THEN
		INSERT INTO `np_bans` VALUES (DEFAULT, `steamId`, `ip`, `name`, ntime, banlength, bantype, serverId, modId, adminUid, adminName, reason, -1);	
	END IF;
	
	SELECT isBan;
END