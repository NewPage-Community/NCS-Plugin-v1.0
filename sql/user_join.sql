CREATE DEFINER=`root`@`%` PROCEDURE `user_join`(
IN
	steamId BIGINT(20),
	serverId SMALLINT(5),
	modId SMALLINT(5),
	ip VARCHAR(24),
	map VARCHAR(128),
	nowTime INT(11),
	nowDay INT(11)
)
    SQL SECURITY INVOKER
BEGIN

	DECLARE puid INT(11) DEFAULT 0;
	DECLARE vipLevel INT(1) DEFAULT 0; /* unused */
	DECLARE banId INT(11) DEFAULT 0;
	DECLARE banT TINYINT(3) DEFAULT 0;
	DECLARE banS SMALLINT(3) DEFAULT 0;
	DECLARE banM SMALLINT(3) DEFAULT 0;
	DECLARE banC INT(11) DEFAULT 0;
	DECLARE banL INT(11) DEFAULT 0;
	DECLARE banR VARCHAR(128);
	DECLARE isBan INT(1) DEFAULT 0;
	DECLARE trackingId INT(11) DEFAULT 0;
	
	SELECT `uid` INTO `puid` FROM `np_users` WHERE `steamid` = `steamId`;
	
	/* Add new user */
	IF (puid <= 0) THEN
		INSERT INTO `np_users` (`steamid`, `firstjoin`) VALUES (`steamId`, `nowTime`);
		SET puid = LAST_INSERT_ID();
		INSERT INTO `np_stats` (`uid`) VALUES (`puid`);
	END IF;

	/* Add analytics */
	INSERT INTO `np_analytics` VALUES (DEFAULT, `puid`, `serverId`, `ip`, `map`, `nowTime`, `nowDay`, -1);
	SET trackingId = LAST_INSERT_ID();

	/* Check ban */
	SELECT `id`, `bType`, `bSrv`, `bSrvMod`, `bCreated`, `bLength`, `bReason` INTO `banId`, `banT`, `banS`, `banM`, `banC`, `banL`, `banR` FROM `np_bans` WHERE `steamid` = `steamId` AND `bRemovedBy` = -1 ORDER BY `bCreated` DESC LIMIT 1;

	IF (ROW_COUNT() > 0) THEN
		IF (banC+banL > UNIX_TIMESTAMP(NOW()) OR !banL) THEN
			IF ((banT = 2 AND banS = serverId) OR (banT = 1 AND banM = modId)) THEN
				SET isBan = 1;
				INSERT INTO np_blocks VALUES (DEFAULT, `banID`, `ip`, `nowTime`);
			END IF;
			IF (!banL) THEN
				SET banC = 0;
			END IF;
		END IF;
    END IF;

	/* results */
	SELECT a.uid, a.username, a.imm, a.spt, a.vip, a.ctb, a.opt, a.adm, a.own, vipLevel, a.grp, b.onlineTotal, b.onlineToday, b.onlineOB, b.onlinePlay, b.connectTimes, b.vitality, trackingId, isBan, banT, banC+banL, banR FROM np_users a, np_stats b WHERE a.uid = puid AND b.uid = puid;
	
END