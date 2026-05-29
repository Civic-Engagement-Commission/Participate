# Decidim NYC

Free Open-Source participatory democracy, citizen participation and open government for cities and organizations

This is the open-source repository for Decidim NYC, based on [Decidim](https://github.com/decidim/decidim) `v0.31.5`.

## Setting up the application

You will need to do some steps before having the app working properly once you have deployed it:

1. Create a System Admin user: `bin/rails decidim_system:create_admin`
1. Visit `<your app url>/system` and log in with your system admin credentials
1. Create a new organization. Check the locales you want to use for that organization, and select a default locale.
1. Set the correct default host for the organization, otherwise the app will not work properly. Note that you need to include any subdomain you might be using.
1. Fill the rest of the form and submit it.

You are good to go!

## Local development

The app runs on Docker. See [docs/DOCKER.md](docs/DOCKER.md).

## License

This repository is a derivative of [Decidim](https://github.com/decidim/decidim), licensed under the [GNU Affero General Public License v3.0](LICENSE-AGPLv3.txt).
