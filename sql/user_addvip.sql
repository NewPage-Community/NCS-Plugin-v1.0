DELIMITER $$
CREATE DEFINER=`root`@`%` PROCEDURE `user_addvip`(
IN
    userId INT(11),
    duration INT(11)
)
    SQL SECURITY INVOKER
BEGIN

	DECLARE expired INT(11) DEFAULT 0;

	/* Check Vip */
	SELECT vipexpired INTO expired FROM `np_users` WHERE uid = userId;

	IF (expired > UNIX_TIMESTAMP()) THEN
		UPDATE `np_users` SET vipexpired = vipexpired + duration WHERE uid = userId;
	ELSE
		UPDATE `np_users` SET vipexpired = UNIX_TIMESTAMP() + duration WHERE uid = userId;
	END IF;

END