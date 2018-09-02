CREATE DEFINER=`root`@`%` PROCEDURE `user_stats`(
IN
    userId INT(11),
    sessionId INT(11),
    todayOnline INT(11),
    totalOnline INT(11),
    specOnline INT(11),
    playOnline INT(11),
    userName VARCHAR(32),
    vipReward INT(11)
)
    SQL SECURITY INVOKER
BEGIN

    /* UPDATE dxg_users */
    UPDATE `np_users` SET lastseen = UNIX_TIMESTAMP(), username = userName, vipreward = vipReward WHERE uid = userId;

    UPDATE `np_stats` SET connectTimes = connectTimes + 1, onlineToday  = onlineToday + todayOnline, onlineTotal = onlineTotal + totalOnline, onlineOB = onlineOB + specOnline, onlinePlay = onlinePlay + playOnline WHERE uid = userId;
        
    UPDATE `np_analytics` SET duration = totalOnline WHERE uid = userId AND id = sessionId;

END