local grab = require('libs.grab')
local main = '%s'

term.clear()

settings.load()
if settings.get('grab_scripts_on_startup') then
    grab.grabAll(main)
end

print('Running ' .. main .. '..\n')
shell.run(main)