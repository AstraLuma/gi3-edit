using Gtk;
using Gdk;

namespace Mark {
    delegate void FileCallback(File? file);
    
    class EditWindow : ApplicationWindow {
        private SourceView svText;
        private ScrolledWindow swText;
        
        private SourceBuffer sbData;
        
        private SourceLanguageManager slman;
        private SourceStyleSchemeManager sssman;
        
        public CommandPalette? command_palette {get; set construct;}
        
        public bool dirty { get {
            return true; // FIXME
        }}
        
        public string? etag {get; private set;}
        public SourceFile source {get; construct;}
        
        public EditWindow(Gtk.Application application, CommandPalette? cp=null) {
            Object(
                application: application, 
                show_menubar: false, 
                command_palette: cp,
                source: new SourceFile()
            );
        }

        public EditWindow.with_file(Gtk.Application application, CommandPalette? cp=null, File file) {
            Object(
                application: application, 
                show_menubar: false, 
                command_palette: cp,
                source: new SourceFile()
            );
            
            // Load file
            this.source.location = file;
            var sfl = new SourceFileLoader(sbData, source);
            sfl.load_async.begin(0, null, (cur, total) => {
                stdout.printf(@"Loading $(cur)/$(total)\n");
            }, (obj, res) => {
                try {
                    sfl.load_async.end(res);
                } catch (Error e) {
                    stderr.printf(@"Error loading: $(e.message)\n");
                    return;
                }
                stdout.printf(@"Guessing language...\n");
                var lang = slman.guess_language(file.get_uri(), sbData.text);
                if (lang != null) {
                    stdout.printf(@"\t$(lang.get_name())\n");
                    sbData.language = lang;
                } else {
                    stdout.printf("\tDunno.\n");
                }
            });
       }
       
       private void build_ui() {
            this.title = Environment.get_application_name();

            swText = new ScrolledWindow(null, null);
            this.add(swText);
            
            svText = new SourceView();
            // Defaults for code editing
            svText.auto_indent = true;
            svText.highlight_current_line = true;
            svText.indent_on_tab = true;
            svText.indent_width = 4;
            svText.insert_spaces_instead_of_tabs = true;
            svText.show_line_marks = true;
            svText.show_line_numbers = true;
            svText.smart_home_end = SourceSmartHomeEndType.BEFORE;
            // TODO: Do this in CSS
            svText.override_font(Pango.FontDescription.from_string(monofont()));
            swText.add(svText);
            
            sbData = svText.buffer as SourceBuffer;
            assert_nonnull(sbData);
            sbData.highlight_matching_brackets = true;
            sbData.highlight_syntax = true;
            // TODO: Have this in an option or action
            sbData.style_scheme = sssman.get_scheme("classic");
            foreach (var scheme in sssman.get_scheme_ids()) {
                stdout.printf(@"Scheme: $scheme\n");
            }
        }
        
        private void populate_actions() {
            this.destroy.connect(() => {
                if (command_palette != null) {
                    command_palette.remove_action_group(this);
                }
            });
            
            this.add_action(mkaction("save", do_save));
            this.add_action(mkaction("save-as", do_save_as)); // TODO: Let this action take an argument
            // TODO: All the languages
        }
                
        construct {
            slman = SourceLanguageManager.get_default();
            sssman = SourceStyleSchemeManager.get_default();
            
            build_ui();
            
            source.notify["location"].connect((_) => {
                if (source.location == null) {
                    title = Environment.get_application_name();
                } else {
                    string dn;
                    try {
                        dn = source.location
                            .query_info(FileAttribute.STANDARD_DISPLAY_NAME, FileQueryInfoFlags.NONE)
                            .get_attribute_string(FileAttribute.STANDARD_DISPLAY_NAME);
                    } catch (Error e) {
                        assert_no_error(e);
                    }
                    assert_nonnull(dn);
                    title = @"$(Environment.get_application_name()):$(dn)";
                }
            });
            
            this.notify["command-palette"].connect((_) => {
                // FIXME: Remove ourselves from the previous group
                command_palette.add_action_group(this);
            });
            
            populate_actions();
        }
                
        private void do_save() {
            if (source.location == null) {
                // Hasn't been saved. Do the save as process, but use the 
                // location it got saved to as the document's location.
                real_save_as((file) => {
                    source.location = file;
                });
                return;
            }
            stdout.printf("Save!\n");
            save_to.begin(source.location, (obj, res) => {
                save_to.end(res);
            });
        }
        
        private void do_save_as() {
            real_save_as(null);
        }
        
        /**
         * All the work of Save As, but returns where it got saved to, or null 
         * if the user cancelled.
         */
        private void real_save_as(FileCallback? fc) {
            stdout.printf("Save as...\n");
            FileChooserDialog fcd = new FileChooserDialog(
                _("Save as..."), this, FileChooserAction.SAVE,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Save"), Gtk.ResponseType.ACCEPT
            );
            fcd.response.connect((response) => {
                if (response == ResponseType.ACCEPT) {
                    var file = fcd.get_file();
                    var uri = fcd.get_uri();
                    assert(file.get_uri() == uri);
                    
                    save_to.begin(file, (obj, res) => {
                        save_to.end(res);
                    });
                    if (fc != null) {
                        Idle.add(() => {
                            fc(file);
                            return false;
                        });
                    }
                }
                fcd.close();
            });
            fcd.show();
        }
        
        /**
         * Writes out to the given file.
         */
        private async void save_to(File dest) {
            var sfs = new SourceFileSaver.with_target(sbData, source, dest);
            // TODO: Set encoding, compression, newlines, flags
            try {
                yield sfs.save_async(0, null, (current, total) => {
                    stdout.printf(@"Saved: $(current)/$(total)\n");
                });
                stdout.printf("Finished save\n");
            } catch (Error e) {
                stderr.printf(@"Error saving: $(e.message)\n");
            }
        }
        
    }
}
