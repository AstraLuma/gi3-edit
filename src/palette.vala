using Gtk;
using Gee;

namespace Mark {
    // Can't use an ActionMap because it doesn't have a way to enumerate all 
    // its contents and we'd still need a lookup to get the collection the 
    // string came from
    class CommandPalette : Object {
        public string prompt {get; set construct; default = " ";}
        // All the maps we search for actions in
        private Collection<GLib.ActionGroup> groups;
        // Cache to look up the group a given action came from
        private Map<string, GLib.ActionGroup> sources;
        
        construct {
            groups = new ArrayList<GLib.ActionGroup>();
            sources = new HashMap<string, GLib.ActionGroup>();
        }
        
        public void add_action_group(GLib.ActionGroup ag) {
            groups.add(ag);
            ag.action_added.connect(clear_sources);
            ag.action_removed.connect(clear_sources);
            sources.clear();
        }

        public void remove_action_group(GLib.ActionGroup ag) {
            ag.action_added.disconnect(clear_sources);
            ag.action_removed.disconnect(clear_sources);
            groups.remove(ag);
            sources.clear();
        }
        
        private void clear_sources (string? _=null) {
            sources.clear();
        }

        private void rebuild_sources() {
            foreach (var ag in groups) {
                foreach (var a in ag.list_actions()) {
                    sources.set(a, ag);
                }
            }
        }
        
        public async void show_async() throws Error, IOError {
            if (sources.is_empty) {
                rebuild_sources();
            }
            
            // 1. pipe all the actions in all the groups to dmenu
            var dmenu = new Subprocess(
                SubprocessFlags.STDIN_PIPE|SubprocessFlags.STDOUT_PIPE,
                "dmenu", "-i", "-p", prompt
            );
            try {
                var actpipe = new DataOutputStream(dmenu.get_stdin_pipe());
                foreach(var ag in groups) {
                    foreach(var a in ag.list_actions()) {
                        var vt = ag.get_action_parameter_type(a);
                        if ((vt == null || vt.is_maybe()) && 
                            ag.get_action_enabled(a) &&
                            a[0] != '-'
                        ) {
                            actpipe.put_string(@"$a\n");
                        }
                    }
                }
                // Flush and wait for for dmenu to slurp it up (yielding in the process)
                yield actpipe.close_async();
            } catch (IOError e) {
                warn_if_reached();
            }
            
            try {
                // 2. Read from dmenu, line-by-line, until it exits
                var runit = new DataInputStream(dmenu.get_stdout_pipe());
                while (!runit.is_closed()) {
                    var line = yield runit.read_line_async();
                    if (line == null || line == "") break;
                    if (line[-1] == '\n') {
                        line = line[0:-1];
                    }
                    
                    // 3. lookup and execute each action from dmenu
                    var grp = sources.get(line);
                    if (grp != null) {
                        Idle.add(() => {
                            grp.activate_action(line, null);
                            return false;
                        });
                    }
                }
            } catch (IOError e) {
                warn_if_reached();
            }
        }
        
        public void show() {
            this.show_async.begin(() => {
            });
        }
    }
}
