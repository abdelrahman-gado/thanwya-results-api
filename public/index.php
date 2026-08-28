<?php

use DI\ContainerBuilder;
use Slim\Factory\AppFactory;
use Slim\Middleware\ContentLengthMiddleware;
use Slim\Psr7\Request;
use Slim\Psr7\Response;

require_once __DIR__ . '/../vendor/autoload.php';

$containerBuilder = new ContainerBuilder();
$containerBuilder->addDefinitions([
    PDO::class => function () {
        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ];

        return new PDO(dsn:'sqlite:/var/www/html/storage/database/database.sqlite', options: $options);
    }
]);

$container = $containerBuilder->build();
AppFactory::setContainer($container);

// Create Slim App
$app = AppFactory::create();
$app->addRoutingMiddleware();

$contentLengthMiddleware = new ContentLengthMiddleware();
$app->add($contentLengthMiddleware);

$errorMiddleware = $app->addErrorMiddleware( true, true, true);

$app->get('/results', function (Request $request, Response $response) use ($container) {
    $queryParams = $request->getQueryParams();
    $seatNumber = $queryParams['seat_no'] ?? null;
    if (!$seatNumber) {
        return $response->withHeader('Content-Type', 'application/json')->withStatus(404, 'not found seat number');
    }

    $pdo = $container->get(PDO::class);
    $stmt = $pdo->prepare('SELECT id, student_name, total_degree, student_case from results where id = :seat_no');
    $stmt->execute([':seat_no' => $seatNumber]);
    $response->getBody()->write(json_encode(['data' => $stmt->fetch()]));
    return $response->withHeader('Content-Type', 'application/json');
});

// Cache routes
$routeCollector = $app->getRouteCollector();
$routeCollector->setCacheFile('/var/www/html/storage/framework/cache.file');

$app->run();

