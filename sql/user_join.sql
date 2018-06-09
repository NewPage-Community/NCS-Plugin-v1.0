CREATE DEFINER=`root`@`%` PROCEDURE `user_join`(
IN
	p_steamId BIGINT(20),
	p_serverId SMALLINT(5),
	p_modId SMALLINT(5),
	p_ip VARCHAR(24),
	p_map VARCHAR(128),
	p_nowTime INT(11),
	p_nowDay INT(11)
)
    SQL SECURITY INVOKER
BEGIN

	DECLARE puid INT(11) DEFAULT 0;
	DECLARE banId INT(11) DEFAULT 0;
	DECLARE banT TINYINT(3) DEFAULT 0;
	DECLARE banS SMALLINT(3) DEFAULT 0;
	DECLARE banM SMALLINT(3) DEFAULT 0;
	DECLARE banC INT(11) DEFAULT 0;
	DECLARE banL INT(11) DEFAULT 0;
	DECLARE banR VARCHAR(128);
	DECLARE isBan INT(1) DEFAULT 0;
	DECLARE TrackingID INT(11) DEFAULT 0;
	DECLARE t_vippoint INT(11);
	DECLARE t_vip BIGINT(20);
	DECLARE b_vip TINYINT(2);
	DECLARE tviplevel TINYINT(2);
	DECLARE BExpired INT(11) DEFAULT 0;
	
	SELECT `uid` INTO puid FROM `np_users` WHERE `steamid` = p_steamId;
	
	/* Add new user */
	IF (ROW_COUNT() <= 0) THEN
		INSERT INTO `np_users` (`steamid`, `firstjoin`) VALUES (p_steamId, p_nowTime);
		SET puid = LAST_INSERT_ID();
		INSERT INTO `np_stats` (`uid`) VALUES (puid);
	END IF;

	/* Add analytics */
	INSERT INTO `np_analytics` VALUES (DEFAULT, puid, p_serverId, p_ip, p_map, p_nowTime, p_nowDay, -1);
	SET TrackingID = LAST_INSERT_ID();

	/* Check Vip */
	SELECT `vipexpired`, `vippoint` INTO t_vip, t_vippoint FROM `np_users` WHERE `uid` = puid;

	IF (t_vip > p_nowTime) THEN
		SET b_vip = 1;
	ELSE
		SET b_vip = 0;
	END IF;

	UPDATE `np_users` SET `vip` = b_vip WHERE `uid` = puid;

	SELECT MAX(a.level) INTO tviplevel FROM np_viplevel a WHERE t_vippoint >= a.point;

	IF (!b_vip) THEN
		SET tviplevel = 0;
	END IF;

	/* Check ban */
	SELECT `id`, `bType`, `bSrv`, `bSrvMod`, `bCreated`, `bLength`, `bReason` INTO banId, banT, banS, banM, banC, banL, banR FROM `np_bans` WHERE `steamid` = p_steamId AND `bRemovedBy` = -1 ORDER BY `bCreated` DESC LIMIT 1;

	IF (ROW_COUNT() > 0) THEN
		IF (banC+banL > UNIX_TIMESTAMP(NOW()) OR !banL) THEN
			IF ((banT = 2 AND banS = p_serverId) OR (banT = 1 AND banM = p_modId)) THEN
				SET isBan = 1;
				INSERT INTO np_blocks VALUES (DEFAULT, banId, p_ip, p_nowTime);
			END IF;
			IF (!banL) THEN
				SET banC = 0;
			END IF;
		END IF;
    END IF;

    SET BExpired = banC + banL;

	/* results */
	SELECT a.uid, a.username, a.imm, a.spt, a.vip, a.ctb, a.opt, a.adm, a.own, tviplevel, a.grp, b.onlineTotal, b.onlineToday, b.onlineOB, b.onlinePlay, b.connectTimes, b.vitality, TrackingID, isBan, banT, BExpired, banR FROM np_users a, np_stats b WHERE a.uid = puid AND b.uid = puid;
	
END