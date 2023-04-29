import tempfile


def before_scenario(context, scenario):
    context.temp_dir = tempfile.TemporaryDirectory()
    context.folder = context.temp_dir.name


def after_scenario(context, scenario):
    context.temp_dir.cleanup()
