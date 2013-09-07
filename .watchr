watch('spec/*\.rb') {|md|
  system("bundle exec rake spec #{md}")
}
