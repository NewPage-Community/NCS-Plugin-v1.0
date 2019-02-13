DELIMITER $$
CREATE DEFINER=`root`@`%` PROCEDURE `user_join`(
IN
	p_steamId BIGINT(20),
	p_serverId SMALLINT(5),
	clientIP VARCHAR(32),
    nowMap VARCHAR(128),
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
	
	SELECT `uid` INTO puid FROM `np_users` WHERE steamid = p_steamId;
	
	/* Add new user */
	IF (ROW_COUNT() <= 0) THEN
		INSERT INTO `np_users` (steamid, firstjoin) VALUES (p_steamId, p_nowTime);
		SET puid = LAST_INSERT_ID();
		INSERT INTO `np_stats` (uid) VALUES (puid);
	END IF;

	/* Add analytics */
	INSERT INTO `np_analytics` VALUES (DEFAULT, puid, p_serverId, clientIP, nowMap, p_nowTime, p_nowDay, -1);
	SET TrackingID = LAST_INSERT_ID();

	/* Check today stats */
	IF (date_format(FROM_UNIXTIME((SELECT lastseen FROM `np_users` WHERE uid = puid)),'%Y%m%d') < p_nowDay) THEN
		UPDATE `np_stats` SET onlineToday = 0 WHERE uid = puid;
		UPDATE `np_users` SET vipreward = 0 WHERE uid = puid;
	END IF;

	/* Check Vip */
	SELECT vipexpired, vippoint INTO t_vip, t_vippoint FROM `np_users` WHERE uid = puid;

	IF (t_vip > p_nowTime) THEN
		SET b_vip = 1;
	ELSE
		SET b_vip = 0;
	END IF;

	/* Save vip level who vip is expired */
	SELECT MAX(a.level) INTO tviplevel FROM np_viplevel a WHERE t_vippoint >= a.point;

	UPDATE `np_users` SET vip = b_vip, viplevel = tviplevel WHERE uid = puid;

	IF (!b_vip) THEN
		SET tviplevel = 0;
	END IF;

	/* results */
	SELECT a.uid AS UID, a.imm AS Imm, a.spt AS Spt, a.vip AS Vip, a.ctb AS Ctb, a.opt AS Opt, a.adm AS Adm, a.own AS Own, tviplevel AS Viplevel, a.grp AS Grp, b.onlineTotal AS OnlineTotal, b.onlineToday AS OnlineToday, b.onlineOB AS OnlineOB, b.onlinePlay AS OnlinePlay, b.connectTimes AS ConnectTimes, b.vitality AS Vitality, TrackingID, a.money AS Money, a.signtimes AS SignTimes, a.signdate AS SignDate, t_vippoint AS VIPPoint, t_vip AS VIPExpired, a.vipreward AS VIPReward, a.namecolor AS NameColor, a.customperfix AS CustomPrefix, a.prefixprefer AS PrefixPrefer FROM np_users a, np_stats b WHERE a.uid = puid AND b.uid = puid;
	
END