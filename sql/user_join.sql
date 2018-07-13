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
	DECLARE TrackingID INT(11) DEFAULT 0;
	DECLARE t_vippoint INT(11);
	DECLARE t_vip BIGINT(20);
	DECLARE b_vip TINYINT(2);
	DECLARE tviplevel TINYINT(2);
	
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

	/* results */
	SELECT a.uid, a.username, a.imm, a.spt, a.vip, a.ctb, a.opt, a.adm, a.own, tviplevel, a.grp, b.onlineTotal, b.onlineToday, b.onlineOB, b.onlinePlay, b.connectTimes, b.vitality, TrackingID FROM np_users a, np_stats b WHERE a.uid = puid AND b.uid = puid;
	
END