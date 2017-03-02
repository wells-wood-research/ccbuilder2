# ccbmk2

## Notes

* `docker-compose up`
* Could I use a type to define the field and then have a single update message for all of the input fields?
* When rebuilding the image, you need to:
    * Rebuild the images using `docker build -t ccbmk2 .`
    * Delete the old `docker-compose` image using `docker-compose rm`
* `docker exec -i -t ccmbmk2_web_1 /bin/bash`
* `docker stop $(docker ps -a -q)` to stop all images
* `docker rm $(docker ps -a -q)` to remove all images
* Coolors
    * https://coolors.co/e6e8e6-ced0ce-9fb8ad-475841-3f403f

## Style Guide

* All CSS that manipulates the *position* of elements should be defined in Elm, all formating (fonts, colours) should be defined in the style sheet.

## TODO

* Add additional camera and representation controls
* Tidy up the update function
* Change build url to `/build-coiledcoil`
* Add `SetRegister` to `EditParameter` message
* Add stats logging with MongoDB
* Independent chains and antiparallels