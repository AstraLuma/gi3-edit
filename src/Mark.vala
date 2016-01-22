using Gtk;
namespace Mark {

    class MarkApp : Gtk.Application {
    
        private void common_setup(EditWindow win) {
            set_accels_for_action("app.-show-palette", {"<Primary><Shift>p"});
            set_accels_for_action("app.open", {"<Primary>o"});
            set_accels_for_action("app.new", {"<Primary>n"});
            // FIXME: do this in the window
            set_accels_for_action("win.save", {"<Primary>s"});
            set_accels_for_action("win.save-as", {"<Primary><Shift>s"});
            set_accels_for_action("win.close-window", {"<Primary>w"});
        }        
        
        protected override void activate () {
            stdout.printf("Activate\n");
            var win = new_window();
            win.show_all();
        }
        
        protected EditWindow new_window(File? file=null) {
            var cp = new CommandPalette();
            cp.add_action_group(this);
            cp.prompt = Environment.get_application_name();
            
            EditWindow win;
            if (file == null) {
                win = new EditWindow(this, cp);
            } else {
                win = new EditWindow.with_file(this, cp, file);
            }
            add_window(win);
            common_setup(win);
            return win;
        }        
        
        protected override void open(File[] files, string hint) {
            stdout.printf(@"Open files ($(hint))\n");
            foreach (var file in files) {
                stdout.printf(@"\t$(file.get_uri())\n");
                var ew = new_window(file);
                ew.show_all();
            }
        }

        public MarkApp () {
            Object(
                application_id: "io.gi3.edit", 
                flags: ApplicationFlags.NON_UNIQUE|ApplicationFlags.HANDLES_OPEN
            );
        }
        
        public static int main(string[] args) {
            warn_if_fail(Thread.supported());
	    /*Intl.bindtextdomain( Config.GETTEXT_PACKAGE, Config.LOCALEDIR );
	    Intl.bind_textdomain_codeset( Config.GETTEXT_PACKAGE, "UTF-8" );
	    Intl.textdomain( Config.GETTEXT_PACKAGE );*/

            Environment.set_application_name(_("Mark"));
            return new MarkApp().run(args);
        }
        
        construct {
            this.add_action(mkaction("quit", () => {
                this.quit();
            }));

            this.add_action(mkaction("new", () => {
                new_window().show_all();
            }));
            this.add_action(mkaction("open", do_open));
            
            this.add_action(mkaction("-show-palette", () => {
                stdout.printf("Palette time\n");
                var ew = active_window as EditWindow;
                assert_nonnull(ew);
                ew.command_palette.show();
            }));

        }
        
        private void do_open() {
            stdout.printf("Open!\n");
            FileChooserDialog fcd = new FileChooserDialog(
                _("Open"), active_window, FileChooserAction.OPEN,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT
            );
            fcd.response.connect((response) => {
                if (response == ResponseType.ACCEPT) {
                    var file = fcd.get_file();
                    var uri = fcd.get_uri();
                    assert(file.get_uri() == uri);
                    
                    open({file}, "");
                }
                fcd.close();
            });
            fcd.show();
        }
   }
}
