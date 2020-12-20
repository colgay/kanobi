#include <amxmodx>

new g_money[MAX_PLAYERS + 1];
new gmsgMoney;
new gmsgBlinkAcct;

public plugin_init()
{
    register_plugin("CS Money", "0.1", "peter5001");

    gmsgMoney = get_user_msgid("Money");
    gmsgBlinkAcct = get_user_msgid("BlinkAcct");

    register_message(gmsgMoney, "MessageMoney");
}

public client_disconnected(id)
{
    g_money[id] = 0;
}

public MessageMoney(msgid, msgdest, id)
{
    set_msg_arg_int(1, ARG_LONG, g_money[id]);
}

public plugin_natives()
{
    register_library("cs_money");

    register_native("csm_set_money", "native_set_money");
    register_native("csm_get_money", "native_get_money");
    register_native("csm_blink_acct", "native_blink_acct");
}

public native_set_money()
{
    new id = get_param(1);
    new val = get_param(2);
    new flash = get_param(3);

    g_money[id] = val;
    
    message_begin(MSG_ONE, gmsgMoney, _, id);
    write_long(val);
    write_byte(flash);
    message_end();
}

public native_get_money()
{
    new id = get_param(1);
    return g_money[id];
}

public native_blink_acct()
{
    new id = get_param(1);

	client_print(id, print_center, "#Cstrike_TitlesTXT_Not_Enough_Money");

	message_begin(MSG_ONE, gmsgBlinkAcct, .player=id);
	write_byte(2);
	message_end();
}