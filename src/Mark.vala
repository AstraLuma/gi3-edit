using Gtk;
namespace Mark {

    class MarkApp : Gtk.Application {
        
        protected override void activate () {
            set_accels_for_action("app.-show-palette", {"<Primary><Shift>p"});
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
            Environment.set_application_name("Mark");
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
                var ew = active_window as EditWindow;
                assert(ew != null);
                ew.command_palette.show();
            }));

        }
        
        private void do_open() {
            stdout.printf("Open!\n");
            FileChooserDialog fcd = new FileChooserDialog(
                "Open", active_window, FileChooserAction.OPEN,
                "_Cancel", Gtk.ResponseType.CANCEL,
				"_Open", Gtk.ResponseType.ACCEPT
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
