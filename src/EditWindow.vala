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
        
        public bool dirty { get; private set; }
        
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
                
                // This has to be done after the changed signal
                // FIXME: More deterministic way to handle this?
                Idle.add(() => {
                    dirty = false;
                    return false;
                });
            });
       }
       
       private void build_ui() {
            update_title();

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
            
            sbData.changed.connect(() => {
                dirty = true;
            });
            
            delete_event.connect(do_delete_event);
            
            focus_in_event.connect((_) => {
                stdout.printf("focus_in_event\n");
                do_file_check();
                return false;
            });
            
            enter_notify_event.connect((_) => {
                stdout.printf("enter_notify_event\n");
                do_file_check();
                return false;
            });
        }
        
        private void populate_actions() {
            this.destroy.connect(() => {
                if (command_palette != null) {
                    command_palette.remove_action_group(this);
                }
            });
            
            this.add_action(mkaction("save", do_save));
            this.add_action(mkaction("save-as", do_save_as)); // TODO: Let this action take an argument
            this.add_action(mkaction("close-window", close));
        }
        
        private void update_title() {
            if (source.location == null) {
                title = Environment.get_application_name();
            } else {
                string? dn = null;
                try {
                    dn = source.location
                        .query_info(FileAttribute.STANDARD_DISPLAY_NAME, FileQueryInfoFlags.NONE)
                        .get_attribute_string(FileAttribute.STANDARD_DISPLAY_NAME);
                } catch (Error e) {
                    assert_no_error(e);
                }
                if (dn == null && !source.location.query_exists()) { // Actually goes out to the filesystem
                    // Not sure if this is the only time dn can be null. 
                    // I thought it could figure out display name by the path alone?
                    dn = @"(new)$(source.location.get_uri())";
                }
                assert_nonnull(dn);
                title = @"$(Environment.get_application_name()):$(dn)";
            }
            if (dirty) {
                title += "*";
            }
        }
                
        construct {
            slman = SourceLanguageManager.get_default();
            sssman = SourceStyleSchemeManager.get_default();
            
            build_ui();
            
            source.notify["location"].connect((_) => {
                update_title();
            });
            
            this.notify["command-palette"].connect((_) => {
                // FIXME: Remove ourselves from the previous group
                command_palette.add_action_group(this);
            });
            
            this.notify["dirty"].connect((_) => {
                update_title();
            });
            
            populate_actions();
            
            // FIXME: When does this need to be refreshed and/or cleaned up?
            try {
                source.location.monitor(FileMonitorFlags.WATCH_HARD_LINKS)
                .changed.connect((file, other, evt) => {
                    source.check_file_on_disk();
                });
            } catch (GLib.Error e) {
                assert_no_error(e);
            }
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
                dirty = false;
                stdout.printf("Finished save\n");
            } catch (Error e) {
                stderr.printf(@"Error saving: $(e.message)\n");
            }
        }
        
        // Checks if the file was externally edited or deleted, and notify the user
        private void do_file_check() {
            if (source.is_deleted() || source.is_externally_modified()) {
                dirty = true;
            }
        }
        
        private bool do_delete_event(EventAny event) {
            // FIXME: Do this more async, less blocking.
            if (!dirty) {
                return false;
            }
            // Prompt user to save or discard.
            var dlg = new Dialog.with_buttons(
                "Unsaved changes!", this, DialogFlags.MODAL,
                "Save", ResponseType.APPLY,
                "Cancel", ResponseType.CANCEL,
                "Don't Save", ResponseType.CLOSE
            );
            // I don't like using run(), recursive event loops just feels wrong
            var resp = dlg.run();
            dlg.destroy();
            
            switch (resp) {
                case ResponseType.DELETE_EVENT:
                case ResponseType.NONE:
                case ResponseType.CANCEL:
                    // Abort the close process
                    return true;
                
                case ResponseType.CLOSE:
                    // Close anyway, ignore the dirty flag
                    return false;
                
                case ResponseType.APPLY:
                    // Save, then exit
                    do_save(); // Totally borrowing the save action handler
                    // Except that save_to() is an async. Crap.
                    return false;
                default:
                    assert_not_reached();
            }
        }
    }
}
