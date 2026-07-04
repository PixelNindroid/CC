local grab = require('libs.grab')
local main = '%s'

term.clear()

settings.load()
if settings.get('grab.grab_scripts_on_startup') then
    grab.grabAll(main)
end

if settings.get('grab.run_main_on_startup') then
    print('Running ' .. main .. '..\n')
    shell.run(main)
end