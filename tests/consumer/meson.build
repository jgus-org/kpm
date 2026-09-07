project('kpm', 'c', version: '0.2.3', license: 'GPL', default_options: [
  'b_ndebug=if-release',
  'c_std=gnu23',
])

KPM_PLATFORM = meson.get_external_property('kindle_platform', get_option('kindle_platform'))
if KPM_PLATFORM == ''
  KPM_PLATFORM = host_machine.cpu_family()
endif
add_global_arguments('-DKPM_PLATFORM="' + KPM_PLATFORM + '"', language: 'c')
add_global_arguments('-DKPM_DB_PATH="' + get_option('db_path') + '"', language: 'c')
add_global_arguments('-DKPM_PKG_PATH="' + get_option('pkg_path') + '"', language: 'c')

kmc_lib_dir = ''
curl_dep = dependency('libcurl')
sqlite3_dep = dependency('sqlite3')
libcjson_dep = dependency('libcjson')
libarchive_dep = dependency('libarchive')

subdir('stubs')
subdir('src')

if get_option('cli').enabled()
  subdir('cli')
endif
