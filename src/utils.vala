using Gdk;

string keymods(Gdk.EventKey key) {
    string ls = "";
    if ((key.state & ModifierType.SHIFT_MASK) != 0) ls += "S";
    if ((key.state & ModifierType.LOCK_MASK ) != 0) ls += "L";
    if ((key.state & ModifierType.CONTROL_MASK) != 0) ls += "C";
    if ((key.state & ModifierType.MOD1_MASK ) != 0) ls += "1";
    if ((key.state & ModifierType.MOD2_MASK ) != 0) ls += "2";
    if ((key.state & ModifierType.MOD3_MASK ) != 0) ls += "3";
    if ((key.state & ModifierType.MOD4_MASK ) != 0) ls += "4";
    if ((key.state & ModifierType.MOD5_MASK ) != 0) ls += "5";
    if ((key.state & ModifierType.SUPER_MASK) != 0) ls += "s";
    if ((key.state & ModifierType.HYPER_MASK) != 0) ls += "H";
    if ((key.state & ModifierType.META_MASK ) != 0) ls += "M";
    return ls;
}

delegate void ActionCallable();

Action mkaction(string name, ActionCallable func) {
    var a = new SimpleAction(name, null);
    // FIXME: Pass this directly without lambda
    a.activate.connect(() => func());
    return a;
}

string monofont() {
    return new GLib.Settings("org.gnome.desktop.interface").get_string("monospace-font-name");
}

