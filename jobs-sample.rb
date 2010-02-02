# Standallone startup?!?

Iyyov.watch do |d|
  d.name     = "hashdot-daemon"
  port       = 3333
  d.version  = "~> 1.0.0"
  d.instance = port.to_s
  d.args    += [ '-p', port ]

  d.log_rotate do |r|
    r.max_size    = 512.meg
    r.generations = 3
    r.gzip        = true
    r.hup         = true
  end

  d.backup do |b|
    b.mode        = :rsync
    b.files       = %w[ mirror state ]
    b.destination = "evrinid-df3-1:/opt/var/backup/#{`hostname -s`}"
    b.when        = "23:00"
  end

  d.backup_db do |b|
  end
end

