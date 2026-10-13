using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PcVideo.Server.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Folders",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Path = table.Column<string>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    Enabled = table.Column<bool>(type: "INTEGER", nullable: false),
                    VideoCount = table.Column<int>(type: "INTEGER", nullable: false),
                    UnplayableCount = table.Column<int>(type: "INTEGER", nullable: false),
                    LastScanAt = table.Column<string>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Folders", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PairedDevices",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    TokenHash = table.Column<string>(type: "TEXT", nullable: false),
                    DeviceName = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false),
                    LastUsedAt = table.Column<string>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PairedDevices", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Settings",
                columns: table => new
                {
                    Key = table.Column<string>(type: "TEXT", nullable: false),
                    Value = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Settings", x => x.Key);
                });

            migrationBuilder.CreateTable(
                name: "Videos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    FolderId = table.Column<int>(type: "INTEGER", nullable: false),
                    FilePath = table.Column<string>(type: "TEXT", nullable: false),
                    FileName = table.Column<string>(type: "TEXT", nullable: false),
                    FileSize = table.Column<long>(type: "INTEGER", nullable: false),
                    DurationSec = table.Column<double>(type: "REAL", nullable: true),
                    Width = table.Column<int>(type: "INTEGER", nullable: true),
                    Height = table.Column<int>(type: "INTEGER", nullable: true),
                    VideoCodec = table.Column<string>(type: "TEXT", nullable: true),
                    AudioCodec = table.Column<string>(type: "TEXT", nullable: true),
                    BitrateKbps = table.Column<int>(type: "INTEGER", nullable: true),
                    Container = table.Column<string>(type: "TEXT", nullable: false),
                    Unplayable = table.Column<bool>(type: "INTEGER", nullable: false),
                    Missing = table.Column<bool>(type: "INTEGER", nullable: false),
                    AddedAt = table.Column<string>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Videos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Videos_Folders_FolderId",
                        column: x => x.FolderId,
                        principalTable: "Folders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Favorites",
                columns: table => new
                {
                    VideoId = table.Column<int>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Favorites", x => x.VideoId);
                    table.ForeignKey(
                        name: "FK_Favorites_Videos_VideoId",
                        column: x => x.VideoId,
                        principalTable: "Videos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlaybackProgress",
                columns: table => new
                {
                    VideoId = table.Column<int>(type: "INTEGER", nullable: false),
                    PositionSec = table.Column<double>(type: "REAL", nullable: false),
                    DurationSec = table.Column<double>(type: "REAL", nullable: false),
                    Completed = table.Column<bool>(type: "INTEGER", nullable: false),
                    LastPlayedAt = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaybackProgress", x => x.VideoId);
                    table.ForeignKey(
                        name: "FK_PlaybackProgress_Videos_VideoId",
                        column: x => x.VideoId,
                        principalTable: "Videos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_CreatedAt",
                table: "Favorites",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Folders_Path",
                table: "Folders",
                column: "Path",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PairedDevices_TokenHash",
                table: "PairedDevices",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlaybackProgress_LastPlayedAt",
                table: "PlaybackProgress",
                column: "LastPlayedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Videos_FilePath",
                table: "Videos",
                column: "FilePath",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Videos_FolderId",
                table: "Videos",
                column: "FolderId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Favorites");

            migrationBuilder.DropTable(
                name: "PairedDevices");

            migrationBuilder.DropTable(
                name: "PlaybackProgress");

            migrationBuilder.DropTable(
                name: "Settings");

            migrationBuilder.DropTable(
                name: "Videos");

            migrationBuilder.DropTable(
                name: "Folders");
        }
    }
}
